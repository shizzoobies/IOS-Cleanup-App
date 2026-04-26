/**
 * KV-backed rate limiter. Two windows enforced per user:
 *   - per-day cap (default 50 free, 5000 pro)
 *   - per-minute burst (default 10 free, 60 pro)
 *
 * KV is eventually consistent. Acceptable for a soft cap; for hard guarantees
 * use Durable Objects (out of scope for v1).
 */

import type { Env } from "../types";

interface RateLimitConfig {
  perDay: number;
  perMinute: number;
}

const FREE_TIER: RateLimitConfig = { perDay: 50, perMinute: 10 };
const PRO_TIER: RateLimitConfig = { perDay: 5000, perMinute: 60 };

export interface RateLimitResult {
  allowed: boolean;
  retryAfterSeconds?: number;
}

export async function checkRateLimit(
  env: Env,
  userId: string,
  tier: "free" | "pro" = "free"
): Promise<RateLimitResult> {
  const config = tier === "pro" ? PRO_TIER : FREE_TIER;
  const now = Date.now();
  const dayBucket = Math.floor(now / 86_400_000);
  const minuteBucket = Math.floor(now / 60_000);

  const dayKey = `rl:${userId}:d:${dayBucket}`;
  const minKey = `rl:${userId}:m:${minuteBucket}`;

  const [dayCountStr, minCountStr] = await Promise.all([
    env.RATE_LIMITS.get(dayKey),
    env.RATE_LIMITS.get(minKey),
  ]);

  const dayCount = dayCountStr ? parseInt(dayCountStr, 10) : 0;
  const minCount = minCountStr ? parseInt(minCountStr, 10) : 0;

  if (dayCount >= config.perDay) {
    return { allowed: false, retryAfterSeconds: 86_400 - (now % 86_400_000) / 1000 };
  }
  if (minCount >= config.perMinute) {
    return { allowed: false, retryAfterSeconds: 60 - (now % 60_000) / 1000 };
  }

  // Increment. Note: race conditions possible due to KV eventual consistency.
  // Acceptable for v1.
  await Promise.all([
    env.RATE_LIMITS.put(dayKey, String(dayCount + 1), { expirationTtl: 86_400 }),
    env.RATE_LIMITS.put(minKey, String(minCount + 1), { expirationTtl: 120 }),
  ]);

  return { allowed: true };
}

export function userTierFromRequest(request: Request): "free" | "pro" {
  // v1.0: trust client. v1.1: validate StoreKit receipts server-side.
  return request.headers.get("X-Subscription-Tier") === "pro" ? "pro" : "free";
}
