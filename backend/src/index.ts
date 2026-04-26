/**
 * SwipeClean Worker proxy.
 *
 * Routes:
 *   GET  /v1/health
 *   POST /v1/analyze
 *   POST /v1/album_suggest
 *   POST /v1/group
 *
 * All POST routes require Bearer auth (a per-device UUID from the iOS app).
 * Anthropic API key is held in env.ANTHROPIC_API_KEY and never exposed.
 */

import { handleAnalyze } from "./routes/analyze";
import { handleAlbumSuggest } from "./routes/albumSuggest";
import { handleGroup } from "./routes/group";
import { jsonResponse, errorResponse } from "./util/http";
import type { Env } from "./types";

const VERSION = "0.1.0";

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const method = request.method;

    try {
      if (method === "GET" && url.pathname === "/v1/health") {
        return jsonResponse({ ok: true, version: VERSION });
      }

      if (method === "POST" && url.pathname === "/v1/analyze") {
        return await handleAnalyze(request, env, ctx);
      }

      if (method === "POST" && url.pathname === "/v1/album_suggest") {
        return await handleAlbumSuggest(request, env, ctx);
      }

      if (method === "POST" && url.pathname === "/v1/group") {
        return await handleGroup(request, env, ctx);
      }

      return errorResponse(404, "not_found");
    } catch (err) {
      console.error("Unhandled error:", err);
      return errorResponse(500, "internal_error");
    }
  },
};
