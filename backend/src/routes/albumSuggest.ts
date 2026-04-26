/**
 * POST /v1/album_suggest
 *
 * Lightweight endpoint that uses cached prior analysis to ask Claude for an
 * album recommendation without re-uploading the image.
 */

import { z } from "zod";
import Anthropic from "@anthropic-ai/sdk";
import type { Env } from "../types";
import { jsonResponse, errorResponse, extractBearerToken } from "../util/http";
import { checkRateLimit, userTierFromRequest } from "../util/rateLimit";
import { computeCacheKey, getCached, setCached } from "../util/cache";
import { ALBUM_SUGGEST_SYSTEM } from "../util/prompts";

const RequestSchema = z.object({
  asset_summary: z.string().min(1).max(200),
  asset_category: z.string().min(1),
  existing_albums: z.array(z.string()).max(50),
});

const ResponseSchema = z.object({
  suggested_album: z.object({
    name: z.string(),
    is_existing: z.boolean(),
    rationale: z.string().max(100),
  }),
});

export async function handleAlbumSuggest(
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

  const { asset_summary, asset_category, existing_albums } = parsed.data;

  const cacheKey = await computeCacheKey([
    asset_summary,
    asset_category,
    JSON.stringify(existing_albums),
  ]);

  const cached = await getCached<z.infer<typeof ResponseSchema>>(env, cacheKey);
  if (cached) {
    return jsonResponse({ ...cached, cached: true, request_id: crypto.randomUUID() });
  }

  const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });

  const userText = [
    `Photo summary: ${asset_summary}`,
    `Category: ${asset_category}`,
    `Existing albums: ${JSON.stringify(existing_albums)}`,
    `\nRespond with JSON:\n{"suggested_album":{"name":"<album name>","is_existing":<bool>,"rationale":"<under 100 chars>"}}`,
  ].join("\n");

  let claudeResponse;
  try {
    claudeResponse = await client.messages.create({
      model: env.HAIKU_MODEL,
      max_tokens: 150,
      system: ALBUM_SUGGEST_SYSTEM,
      messages: [{ role: "user", content: userText }],
    });
  } catch (err) {
    console.error("Anthropic call failed:", err);
    return errorResponse(502, "upstream_error");
  }

  const textBlock = claudeResponse.content.find((c) => c.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    return errorResponse(502, "upstream_invalid");
  }

  let parsedJson: unknown;
  try {
    const cleaned = textBlock.text.replace(/```json|```/g, "").trim();
    parsedJson = JSON.parse(cleaned);
  } catch {
    return errorResponse(502, "upstream_invalid_json");
  }

  const validated = ResponseSchema.safeParse(parsedJson);
  if (!validated.success) {
    return errorResponse(502, "upstream_schema_mismatch", validated.error.message);
  }

  ctx.waitUntil(setCached(env, cacheKey, validated.data));

  return jsonResponse({
    ...validated.data,
    cached: false,
    request_id: crypto.randomUUID(),
  });
}
