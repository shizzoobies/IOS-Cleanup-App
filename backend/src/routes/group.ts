/**
 * POST /v1/group
 *
 * Refines a batch of perceptual-hash-similar items into confirmed groups
 * with a best representative for each. Uses Claude Sonnet for the harder
 * reasoning.
 */

import { z } from "zod";
import Anthropic from "@anthropic-ai/sdk";
import type { Env } from "../types";
import { jsonResponse, errorResponse, extractBearerToken } from "../util/http";
import { checkRateLimit, userTierFromRequest } from "../util/rateLimit";
import { GROUP_SYSTEM } from "../util/prompts";

const MAX_ITEMS = 20;

const ItemSchema = z.object({
  id: z.string().min(1),
  thumbnail_b64: z.string().min(1),
  metadata: z.object({
    captured_at: z.string().optional(),
    byte_size: z.number(),
  }),
});

const RequestSchema = z.object({
  items: z.array(ItemSchema).min(2).max(MAX_ITEMS),
  max_items: z.number().max(MAX_ITEMS).optional(),
});

const GroupSchema = z.object({
  group_id: z.string(),
  item_ids: z.array(z.string()),
  best_representative_id: z.string(),
  reason: z.string(),
  duplicate_confidence: z.number().min(0).max(1),
});

const ResponseSchema = z.object({
  groups: z.array(GroupSchema),
});

export async function handleGroup(
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

  const { items } = parsed.data;

  const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });

  const itemList = items
    .map(
      (item) =>
        `- ID: ${item.id}, captured: ${item.metadata.captured_at ?? "unknown"}, size: ${item.metadata.byte_size} bytes`
    )
    .join("\n");

  const userText = [
    `Here are ${items.length} images. For each, I'll provide an ID and metadata. Group them, pick the best representative for each group, and explain.`,
    `\nItems:\n${itemList}`,
    `\nRespond with JSON:\n{"groups":[{"group_id":"<string>","item_ids":["<string>"],"best_representative_id":"<string>","reason":"<short string>","duplicate_confidence":<0-1>}]}`,
    `\nPicking the best representative: prefer sharper images, better composition, larger file size as a tiebreaker.`,
  ].join("\n");

  const imageBlocks: Anthropic.ImageBlockParam[] = items.map((item) => ({
    type: "image" as const,
    source: {
      type: "base64" as const,
      media_type: "image/jpeg" as const,
      data: item.thumbnail_b64,
    },
  }));

  let claudeResponse;
  try {
    claudeResponse = await client.messages.create({
      model: env.SONNET_MODEL,
      max_tokens: 800,
      system: GROUP_SYSTEM,
      messages: [
        {
          role: "user",
          content: [...imageBlocks, { type: "text", text: userText }],
        },
      ],
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

  return jsonResponse({
    ...validated.data,
    request_id: crypto.randomUUID(),
  });
}
