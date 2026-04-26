# Instructions for Claude Code

You're picking up SwipeClean, an iOS decluttering app powered by the Anthropic API. The project has been spec'd and scaffolded. Your job is to flesh it out into a working app.

## Read these in order

1. `docs/PRODUCT_SPEC.md` — what we're building and why
2. `docs/ARCHITECTURE.md` — how the pieces fit together
3. `docs/API_CONTRACT.md` — the proxy ↔ app contract
4. `docs/CLAUDE_PROMPTS.md` — system prompts for the API calls
5. `docs/BUILD_PLAN.md` — phased build order with acceptance criteria

## Hard rules (do not violate)

- **Never put the Anthropic API key in the iOS app.** All Claude calls go through the backend proxy. The iOS app talks to the proxy, never directly to `api.anthropic.com`.
- **Originals never leave the device.** Only downsampled thumbnails (max 512px on the long edge, JPEG quality 0.7) get sent to the proxy.
- **Strip EXIF before upload** unless the user has opted into location-aware filing.
- **Faces are blurred in thumbnails** sent to the API unless the user has opted into face analysis (default off).
- **Deletion is always batched and confirmed** through the iOS native PHAssetChangeRequest flow. Never delete silently.
- **No `print()` statements in production paths.** Use `os.Logger` with appropriate subsystem/category.
- **No em dashes anywhere in code comments, docs, or UI strings.** This is a project-wide rule.

## Code style

- Swift 5.9+, iOS 17+ deployment target, SwiftUI + SwiftData + Observation framework
- MVVM with `@Observable` view models (not ObservableObject)
- Async/await everywhere; no completion handlers
- One type per file, named after the type
- Tests use Swift Testing (`@Test`) not XCTest

## Backend style

- TypeScript on Cloudflare Workers
- Strict mode on, no `any`
- Validation with zod
- Anthropic SDK for the proxy calls

## When in doubt

- Prefer on-device Vision/PhotoKit over API calls. Every call costs money.
- Cache aggressively by perceptual hash.
- Defer features. v1 is photos + files, swipe + inspect + file/delete. That's it.
- If a decision could go either way, write the simpler version and leave a `// TODO(scope):` comment.

## What's stubbed vs. what needs building

The skeleton has:
- File structure
- Empty Swift files with documented protocols and minimal types
- Backend Worker scaffolding with one route stubbed
- All docs

You need to build:
- The actual implementations
- Xcode project file (use `xcodegen` or create manually in Xcode)
- Tests
- CI (optional for v1)

Start with Phase 1 in BUILD_PLAN.md.
