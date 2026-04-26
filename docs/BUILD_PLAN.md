# SwipeClean — Build Plan

Phased build order. Each phase has explicit acceptance criteria. Don't move to the next phase until the current one passes.

## Phase 0: Project setup (half a day)

- [ ] Create Xcode project: iOS 17+, SwiftUI app, SwiftData enabled
- [ ] Drag the existing `SwipeClean/` source folder into the project
- [ ] Add Info.plist entries:
  - `NSPhotoLibraryUsageDescription`
  - `NSPhotoLibraryAddUsageDescription`
  - `NSCameraUsageDescription` (only if needed for v1, probably not)
- [ ] Set up Cloudflare Worker: `cd backend && npm install && wrangler dev`
- [ ] Verify `/v1/health` returns 200 from the local Worker

**Done when:** Empty app builds and runs on simulator, Worker responds locally.

## Phase 1: Photo access and asset enumeration (1-2 days)

- [ ] Implement `PhotoLibraryService` with permission request and `PHAsset` fetching
- [ ] Build `AssetRepository` that returns paginated `[Asset]` from PhotoKit
- [ ] Build basic `Asset` domain model (wraps `PHAsset` identifier + cached metadata)
- [ ] Wire up a debug view that lists asset thumbnails in a grid
- [ ] Handle the limited-library access case (iOS lets users grant partial access)

**Done when:** App requests permission, shows grid of thumbnails with date labels, scrolls smoothly with 5,000+ assets.

## Phase 2: On-device Vision analysis (2-3 days)

- [ ] Implement `PerceptualHasher` using `VNGenerateImageFeaturePrintRequest`
- [ ] Implement `BlurDetector` using Core Image Laplacian variance
- [ ] Implement `FaceDetector` using `VNDetectFaceRectanglesRequest`
- [ ] Implement `TextRecognizer` using `VNRecognizeTextRequest` (for receipts/docs)
- [ ] Implement `OnDeviceClassifier` using `VNClassifyImageRequest`
- [ ] Build `VisionPipeline` that runs all of the above on an asset and returns `LocalAnalysis`
- [ ] Cache `LocalAnalysis` in SwiftData keyed by asset identifier

**Done when:** Pre-pass on 1,000 assets completes in under 60 seconds on iPhone 13+, results cached, similar images cluster together by perceptual hash distance.

## Phase 3: Backend proxy (1-2 days)

- [ ] Wire up `/v1/analyze` endpoint with full validation
- [ ] Add KV-backed rate limiting per user_id
- [ ] Add KV-backed response caching by content hash
- [ ] Implement face-blur preprocessing check (reject thumbnails that don't have face_blur_applied flag if has_faces=true and user hasn't opted in)
- [ ] Wire up `/v1/album_suggest` endpoint
- [ ] Wire up `/v1/group` endpoint
- [ ] Add structured logging (request_id, user_id, model, latency, cache_hit)
- [ ] Deploy to Cloudflare Workers staging

**Done when:** All three endpoints return valid responses end-to-end, rate limits enforce, cache hits return in under 100ms, staging deploy is reachable from the iOS app.

## Phase 4: Claude service client (iOS) (1 day)

- [ ] Implement `ClaudeService` with async methods for each endpoint
- [ ] Implement thumbnail downsampling (Core Image, 512px long edge, q=0.7)
- [ ] Implement face blurring on thumbnails (Vision detect + CIFilter blur regions)
- [ ] Implement EXIF stripping
- [ ] Wire up Keychain-backed user token (UUID at first launch)
- [ ] Add retry logic with exponential backoff
- [ ] Add offline detection and graceful degradation

**Done when:** Calling `analyze(asset:)` from a debug view returns a real Claude categorization within 2 seconds, faces are blurred in the upload (verify by inspecting the request body in the Worker), no API key visible in app binary.

## Phase 5: Smart queue and grouping (2 days)

- [ ] Implement `QueueBuilder` that takes the asset list, runs the Vision pipeline, and produces categorized queues:
  - Duplicates
  - Screenshots
  - Blurry
  - Large files (>50MB)
  - Old & untouched (>2 years, never opened)
  - Receipts/documents
  - Everything else
- [ ] Build queue selection screen
- [ ] Implement undo stack (last 10 actions)

**Done when:** Opening the app shows the user "We found 142 likely duplicates and 67 screenshots, where do you want to start?", and tapping a category loads that queue.

## Phase 6: Swipe deck UI (2-3 days)

- [ ] Build `SwipeCardView` with gesture handlers (left, right, up)
- [ ] Build `SwipeDeckView` that renders a stack of cards
- [ ] Implement card animations (drag, snap-back, fly-off)
- [ ] Wire up actions: keep, delete (queue), skip
- [ ] Show AI summary on the card
- [ ] Tap to enter inspect mode
- [ ] Long-press to show "why grouped" panel
- [ ] Implement pending-deletion tray with running count
- [ ] Implement 50-swipe checkpoint that calls `PHAssetChangeRequest.deleteAssets`

**Done when:** User can swipe through 50 photos, see Claude summaries, queue deletions, and confirm batch deletion via iOS native dialog.

## Phase 7: Inspect mode (1-2 days)

- [ ] Build `InspectView` with full-resolution image and pinch-to-zoom
- [ ] Add metadata panel (date, location with mini-map, camera, dimensions)
- [ ] Add "similar items" carousel
- [ ] Add Claude rationale section
- [ ] Add video scrubber for video assets
- [ ] Add QuickLook for files

**Done when:** Tapping any card opens inspect, gestures work, metadata is correct, swipe-to-act from inspect mode works.

## Phase 8: Album filing (2 days)

- [ ] After swipe-right, show `AlbumPickerSheet` with Claude's suggestion at the top
- [ ] Allow user to accept, pick a different existing album, create new album, or skip filing
- [ ] Implement album CRUD via PhotoKit (`PHAssetCollectionChangeRequest`)
- [ ] Track filing decisions in SwiftData for future personalization

**Done when:** Swipe-right on a recipe screenshot offers "File in Recipes?" and the photo actually appears in the Recipes album after confirmation.

## Phase 9: Files integration (2 days)

- [ ] Implement `FileAccessService` using `UIDocumentPickerViewController`
- [ ] Enumerate files from picked folders
- [ ] Run a file-content analysis pipeline (filename, size, last modified, optional content extract for PDFs)
- [ ] Wire files into the same swipe deck UI
- [ ] Implement file deletion via `FileManager`

**Done when:** User can pick a folder, see its files in the swipe deck, get Claude analysis, swipe to keep/delete, and have the deletions actually happen.

## Phase 10: Onboarding and privacy (1-2 days)

- [ ] Build onboarding flow (4 screens: welcome, privacy explainer, permissions, ready)
- [ ] Add privacy settings screen (face-aware analysis, location-aware filing, etc.)
- [ ] Add app-wide analytics opt-in (default off)
- [ ] Add privacy manifest (`PrivacyInfo.xcprivacy`)

**Done when:** First launch flows naturally to first cleanup session, privacy settings persist, App Privacy in App Store Connect is fully filled out.

## Phase 11: Monetization (2 days)

- [ ] Set up StoreKit 2 products: monthly, yearly, Big Cleanup pack
- [ ] Build paywall view triggered after 50 free swipes
- [ ] Implement entitlement checks server-side (validate StoreKit receipts in Worker)
- [ ] Implement free tier rate limiting tied to entitlements

**Done when:** Free user hits the paywall after 50 swipes, can purchase Pro, and immediately gets unlimited swipes plus AI filing.

## Phase 12: Polish and ship (1 week)

- [ ] Loading states everywhere
- [ ] Empty states everywhere
- [ ] Error states with retry
- [ ] Haptics on swipe actions
- [ ] Sound design (optional, off by default)
- [ ] App icon and screenshots
- [ ] App Store listing copy
- [ ] TestFlight beta with 10-20 users
- [ ] Address feedback
- [ ] Submit to App Store

**Done when:** App is approved and live.

## Total estimate

About 4-5 weeks of full-time work for an experienced Swift developer. Claude Code can compress this significantly if you give it the right context per phase.
