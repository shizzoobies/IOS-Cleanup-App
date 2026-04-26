# SwipeClean Backend Proxy

A Cloudflare Worker that wraps the Anthropic API for the SwipeClean iOS app.

## Why a proxy?

- **Key safety:** the Anthropic key never ships in the iOS binary
- **Rate limiting:** prevents one user from torching the API budget
- **Caching:** identical thumbnails return from KV in <100ms
- **Validation:** rejects oversized payloads and bad inputs at the edge

## Local setup

```bash
npm install
wrangler kv:namespace create CACHE
wrangler kv:namespace create RATE_LIMITS
# Paste the returned IDs into wrangler.toml

wrangler secret put ANTHROPIC_API_KEY
# Paste your key when prompted

npm run dev
# Worker runs at http://localhost:8787
```

Test:
```bash
curl http://localhost:8787/v1/health
# {"ok":true,"version":"0.1.0"}
```

## Deploy

```bash
npm run deploy
```

## Endpoints

See `../docs/API_CONTRACT.md` for full schemas.

## Cost expectations

At Haiku pricing with thumbnail + metadata input (~1500 tokens) and ~200 token responses, each `/v1/analyze` call costs roughly $0.0015. A user cleaning 1,000 photos costs about $1.50 in upstream API spend, well within the Pro tier ($4.99/mo) margin.

## What's stubbed

- `/v1/analyze` is fully implemented
- `/v1/album_suggest` is stubbed (501)
- `/v1/group` is stubbed (501)

Both are wired into the router and ready for Claude Code to flesh out. They follow the same pattern as `analyze.ts`.
