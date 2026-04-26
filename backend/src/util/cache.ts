/**
 * Content-addressed cache for Anthropic responses.
 * Key is sha256(thumbnail_b64 + canonicalized_metadata).
 * TTL: 30 days.
 */

import type { Env } from "../types";

const CACHE_TTL_SECONDS = 30 * 24 * 60 * 60;

export async function computeCacheKey(parts: string[]): Promise<string> {
  const concatenated = parts.join("|");
  const encoder = new TextEncoder();
  const data = encoder.encode(concatenated);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const bytes = new Uint8Array(hashBuffer);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function getCached<T>(env: Env, key: string): Promise<T | null> {
  const raw = await env.CACHE.get(`v1:${key}`);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

export async function setCached<T>(env: Env, key: string, value: T): Promise<void> {
  await env.CACHE.put(`v1:${key}`, JSON.stringify(value), {
    expirationTtl: CACHE_TTL_SECONDS,
  });
}
