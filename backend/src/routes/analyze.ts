/**
 * POST /v1/analyze
 *
 * Validates input, checks cache, calls Anthropic, validates output, returns.
 */

import { z } from "zod";
import Anthropic from "@anthropic-ai/sdk";
import type { Env } from "../types";
import { jsonResponse, errorResponse, extractBearerToken } from "../util/http";
import { checkRateLimit, userTierFromRequest } from "../util/rateLimit";
import { computeCacheKey, getCached, setCached } from "../util/cache";
import { ANALYZE_SYSTEM } from "../util/prompts";

const MAX_THUMBNAIL_BYTES = 512 * 1024;

const RequestSchema = z.object({
  thumbnail_b64: z.string().min(1),
  metadata: z.object({
    asset_type: z.enum(["photo", "video", "screenshot", "document", "other"]),
    captured_at: z.string().optional(),
    duration_seconds: z.number().optional(),
    byte_size: z.number(),
    vision_labels: z.array(z.string()).optional(),
    ocr_text: z.string().max(500).optional(),
    is_screenshot: z.boolean(),
    has_faces: z.boolean(),
  }),
  existing_albums: z.array(z.string()).max(50),
  options: z
    .object({
      suggest_album: z.boolean().default(true),
      include_rationale: z.boolean().default(false),
    })
    .default({ suggest_album: true, include_rationale: false }),
});

const ResponseSchema = z.object({
  category: z.enum([
    "photo",
    "screenshot",
    "document",
    "receipt",
    "meme",
    "social",
    "art",
    "nature",
    "food",
    "people",
    "pet",
    "place",
    "other",
  ]),
  summary: z.string().max(200),
  suggested_album: z
    .object({
      name: z.string(),
      is_existing: z.boolean(),
      confidence: z.number().min(0).max(1),
    })
    .nullable(),
});

export async function handleAnalyze(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const token = extractBearerToken(request);
  if (!token) return errorResponse(401, "unauthorized");

  const tier = userTierFromRequest(request);
  const rl = await checkRateLimit(env, token, tier);
  if (!rl.allowed) {
    return jsonResponse(
      { error: "rate_limit", retry_after_seconds: rl.retryAfterSeconds ?? 3600 },
      429
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return errorResponse(400, "invalid_json");
  }

  const parsed = RequestSchema.safeParse(body);
  if (!parsed.success) {
    return errorResponse(400, "invalid_request", parsed.error.message);
  }

  const { thumbnail_b64, metadata, existing_albums, options } = parsed.data;

  // Check thumbnail size.
  const approxBytes = Math.floor((thumbnail_b64.length * 3) / 4);
  if (approxBytes > MAX_THUMBNAIL_BYTES) {
    return errorResponse(413, "payload_too_large");
  }

  // Cache lookup.
  const cacheKey = await computeCacheKey([
    thumbnail_b64.slice(0, 64),
    JSON.stringify(metadata),
    JSON.stringify(existing_albums),
    JSON.stringify(options),
  ]);

  const cached = await getCached<z.infer<typeof ResponseSchema>>(env, cacheKey);
  if (cached) {
    return jsonResponse({
      ...cached,
      cached: true,
      request_id: crypto.randomUUID(),
    });
  }

  // Call Anthropic.
  const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });

  const userText = [
    `Analyze this asset. Metadata: ${JSON.stringify(metadata)}.`,
    `Existing albums: ${JSON.stringify(existing_albums)}.`,
    options.suggest_album
      ? "Suggest the best album from the existing list, or propose a new album name if none fit well."
      : "",
    `Respond with JSON matching this schema: { "category": "<one of the categories>", "summary": "<under 140 chars>", "suggested_album": { "name": "<string>", "is_existing": <bool>, "confidence": <0-1> } | null }`,
  ]
    .filter(Boolean)
    .join(" ");

  let claudeResponse;
  try {
    claudeResponse = await client.messages.create({
      model: env.HAIKU_MODEL,
      max_tokens: 300,
      system: ANALYZE_SYSTEM,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: "image/jpeg",
                data: thumbnail_b64,
              },
            },
            { type: "text", text: userText },
          ],
        },
      ],
    });
  } catch (err) {
    console.error("Anthropic call failed:", err);
    return errorResponse(502, "upstream_error");
  }

  // Extract text content from response.
  const textBlock = claudeResponse.content.find((c) => c.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    return errorResponse(502, "upstream_invalid");
  }

  let parsedJson: unknown;
  try {
    // Strip any accidental code fences.
    const cleaned = textBlock.text.replace(/```json|```/g, "").trim();
    parsedJson = JSON.parse(cleaned);
  } catch {
    return errorResponse(502, "upstream_invalid_json");
  }

  const validated = ResponseSchema.safeParse(parsedJson);
  if (!validated.success) {
    return errorResponse(502, "upstream_schema_mismatch", validated.error.message);
  }

  // Cache successful responses.
  ctx.waitUntil(setCached(env, cacheKey, validated.data));

  return jsonResponse({
    ...validated.data,
    cached: false,
    request_id: crypto.randomUUID(),
  });
}
