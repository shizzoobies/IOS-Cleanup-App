# SwipeClean — API Contract

The iOS app talks only to the backend proxy. The proxy talks to Anthropic. All requests are HTTPS with `Authorization: Bearer <user_token>` header (issued at app first-launch, stored in Keychain).

Base URL (production): `https://api.swipeclean.app`
Base URL (dev): `http://localhost:8787`

## POST /v1/analyze

Analyze a single asset and return categorization, summary, and (optionally) album suggestion.

**Request:**
```json
{
  "thumbnail_b64": "string (base64 JPEG, max 512px long edge, q=0.7)",
  "metadata": {
    "asset_type": "photo | video | screenshot | document",
    "captured_at": "ISO8601 string, optional",
    "duration_seconds": "number, optional (for video)",
    "byte_size": "number",
    "vision_labels": ["array of on-device classifier labels, optional"],
    "ocr_text": "string, optional, max 500 chars",
    "is_screenshot": "boolean",
    "has_faces": "boolean"
  },
  "existing_albums": ["array of album names, max 50"],
  "options": {
    "suggest_album": true,
    "include_rationale": false
  }
}
```

**Response 200:**
```json
{
  "category": "string (one of: photo, screenshot, document, receipt, meme, social, art, nature, food, people, pet, place, other)",
  "summary": "string, max 140 chars",
  "suggested_album": {
    "name": "string",
    "is_existing": true,
    "confidence": 0.92
  } | null,
  "rationale": "string, optional, only if include_rationale=true",
  "cached": true,
  "request_id": "string (uuid)"
}
```

**Response 429:** rate limit exceeded
```json
{ "error": "rate_limit", "retry_after_seconds": 3600 }
```

**Response 413:** payload too large (thumbnail over 512KB)
```json
{ "error": "payload_too_large" }
```

## POST /v1/group

Given a batch of items pre-grouped on-device by perceptual hash, ask Claude to refine the grouping and pick the best representative.

**Request:**
```json
{
  "items": [
    {
      "id": "string (asset identifier)",
      "thumbnail_b64": "string",
      "metadata": { "captured_at": "...", "byte_size": 0 }
    }
  ],
  "max_items": 20
}
```

**Response 200:**
```json
{
  "groups": [
    {
      "group_id": "string",
      "item_ids": ["string"],
      "best_representative_id": "string",
      "reason": "string",
      "duplicate_confidence": 0.95
    }
  ],
  "request_id": "string"
}
```

## POST /v1/album_suggest

Light endpoint for getting just an album suggestion when the user swipes right and we already have analysis cached.

**Request:**
```json
{
  "asset_summary": "string (from a prior /analyze call)",
  "asset_category": "string",
  "existing_albums": ["string"]
}
```

**Response 200:**
```json
{
  "suggested_album": {
    "name": "string",
    "is_existing": true,
    "rationale": "string, max 100 chars"
  }
}
```

## GET /v1/health

Liveness probe. No auth required.

**Response 200:**
```json
{ "ok": true, "version": "string" }
```

## Authentication

App generates a UUID at first launch, stores in Keychain, sends as `Authorization: Bearer <uuid>` on every request. Worker uses this to track per-user rate limits in KV.

For Pro users, the app also includes `X-Subscription-Tier: pro` (validated server-side against StoreKit receipts in v1.1; trust client for v1.0 alpha).

## Rate limits

| Tier | Per-day | Per-minute |
|---|---|---|
| Free | 50 analyze calls | 10 |
| Pro | 5,000 analyze calls | 60 |
| Burst (Big Cleanup) | 10,000/7d | 120 |

## Caching

- Worker computes a content hash of (thumbnail_b64 + metadata) and checks KV before forwarding to Anthropic.
- Cache TTL: 30 days.
- App also caches by perceptual hash in SwiftData (longer-term, per-device).

## Error handling

All errors return JSON with `error` (snake_case slug) and optional `message`. Client should display a friendly message and degrade to on-device-only mode for retryable errors.
