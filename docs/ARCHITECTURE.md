# SwipeClean — Technical Architecture

## Stack

- **iOS app:** Swift 5.9+, SwiftUI, SwiftData, Observation framework, iOS 17+
- **On-device intelligence:** Vision, PhotoKit, Core Image
- **Backend proxy:** TypeScript on Cloudflare Workers
- **AI:** Anthropic API (Claude Haiku 4.5 for per-item, Claude Sonnet 4.6 for grouping)

## High-level diagram

```
┌─────────────────────────────────────────────────┐
│           SwiftUI App (iOS 17+)                 │
│  ┌──────────────────────────────────────────┐  │
│  │  Views: SwipeDeck, Inspect, Sessions     │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │  ViewModels (@Observable)                │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
            │
   ┌────────┴────────┬─────────────┬──────────────┐
   ▼                 ▼             ▼              ▼
┌──────────┐  ┌─────────────┐ ┌──────────┐  ┌──────────┐
│ PhotoKit │  │   Vision    │ │  Files   │  │  Claude  │
│ (photos, │  │  (on-device │ │  (Doc    │  │ Service  │
│  albums) │  │   analysis) │ │  Picker) │  │  client  │
└──────────┘  └─────────────┘ └──────────┘  └─────┬────┘
                                                   │ HTTPS
                                            ┌──────▼──────┐
                                            │ CF Worker   │
                                            │ proxy +     │
                                            │ rate limit  │
                                            └──────┬──────┘
                                                   │
                                            ┌──────▼──────┐
                                            │ Anthropic   │
                                            │   API       │
                                            └─────────────┘
```

## Layer breakdown

### 1. Photo and file access (Swift, on-device)

**PhotoKit (`Photos` framework):**
- `PHPhotoLibrary` for full library access with explicit user permission
- `PHAsset` enumeration with `PHFetchOptions` (sorted by date, filtered by media type)
- `PHImageManager` for thumbnail loading; never load full-res except in inspect mode
- `PHAssetCollection` for album CRUD
- Deletion via `PHAssetChangeRequest.deleteAssets()` which triggers the iOS native confirmation

**Files (`UniformTypeIdentifiers` + `FileManager`):**
- `UIDocumentPickerViewController` for one-time folder access (security-scoped bookmarks)
- `FileManager.default` for enumeration and metadata
- `URL.startAccessingSecurityScopedResource()` for sandboxed access

### 2. On-device intelligence (Vision)

This runs entirely locally and handles the bulk filtering before Claude ever sees anything.

| Job | Apple framework | Purpose |
|---|---|---|
| Perceptual hashing | Vision `VNGenerateImageFeaturePrintRequest` | Find near-duplicates by visual similarity |
| Blur detection | Custom Laplacian variance via Core Image | Flag low-quality shots |
| Screenshot detection | `PHAsset.mediaSubtypes.contains(.photoScreenshot)` | Native flag |
| Face detection | `VNDetectFaceRectanglesRequest` | Mark photos with faces, used for privacy gating and blurring |
| Text detection | `VNRecognizeTextRequest` | Identify documents, receipts, recipes |
| Object/scene labels | `VNClassifyImageRequest` | First-pass categorization |

The on-device classifier handles roughly 80% of categorization for free. Claude is only invoked when real reasoning is needed (e.g., "is this the same hike as last year, or different?").

### 3. Claude integration

**Backend proxy is mandatory.** Reasons:
- API key safety: never ship `ANTHROPIC_API_KEY` in an iOS binary, it gets extracted
- Rate limiting per user: prevent abuse
- Caching: identical thumbnails should hit a cache, not the API
- Cost control: reject oversized requests at the edge

**Cloudflare Workers** chosen because:
- Free tier covers v1 launch volume
- Global edge, low latency
- KV storage for cache and rate limits
- Anthropic SDK works in Workers runtime

**Endpoints** (see `API_CONTRACT.md` for full schemas):
```
POST /v1/analyze        # single-item categorization
POST /v1/group          # batch grouping decisions
POST /v1/album_suggest  # filing recommendation
GET  /v1/health         # liveness probe
```

**Model choices:**
- Per-item analysis and album suggestion: `claude-haiku-4-5`
- Grouping and complex reasoning: `claude-sonnet-4-6`
- Document analysis (multi-page PDFs): Files API with Sonnet

**Cost model:**
- Thumbnail + metadata input ≈ 1,500 tokens
- Response ≈ 200 tokens
- Haiku at current pricing ≈ $0.0015/analysis
- 1,000 photos cleaned ≈ $1.50 in API cost
- Pro tier at $4.99/mo covers this with margin

### 4. App data layer (SwiftData)

```swift
@Model class Session {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var category: QueueCategory
    var decisions: [Decision]
}

@Model class Decision {
    var id: UUID
    var assetIdentifier: String  // PHAsset localIdentifier
    var action: DecisionAction   // keep | delete | skip
    var albumName: String?       // if filed
    var createdAt: Date
    var undone: Bool
}

@Model class CachedAnalysis {
    var perceptualHash: String   // primary key
    var category: String
    var summary: String
    var suggestedAlbum: String?
    var cachedAt: Date
}

@Model class AlbumSuggestion {
    var id: UUID
    var assetIdentifier: String
    var suggestedName: String
    var accepted: Bool?
    var createdAt: Date
}
```

Caching by perceptual hash means re-running cleanup on the same photos doesn't re-hit the API.

## Data flow: single swipe

```
User opens session
  → Fetch PHAsset list, run Vision pre-pass on-device
  → Group items by perceptual hash and content type
  → Pick first item, load thumbnail
  → Send thumbnail + metadata to backend → Claude Haiku
  → Display card with AI context

User swipes right (keep)
  → Claude Haiku call: given image and existing albums, suggest filing
  → User approves / overrides / skips
  → PhotoKit: add asset to selected PHAssetCollection
  → SwiftData: log Decision

User swipes left (delete)
  → Add PHAsset to pending deletion array
  → No API call, no PhotoKit call yet
  → Move to next card

End of session (or 50-swipe checkpoint)
  → PHAssetChangeRequest.deleteAssets(pendingArray)
  → iOS shows native "Delete N photos?" sheet
  → User confirms → photos go to Recently Deleted (30-day recovery)
```

## Privacy by design

1. Thumbnail downsampling happens on-device before upload (max 512px, JPEG q=0.7).
2. EXIF stripped unless user opts into location-aware filing.
3. Faces blurred via Vision face detection + Core Image blur, unless user opts in.
4. Backend proxy is stateless. No persistent storage of thumbnails. Logs are request counts only.
5. Local-first by default. Duplicate detection, blur detection, and basic categorization all work offline.

## Failure modes and mitigations

| Risk | Mitigation |
|---|---|
| User accidentally deletes important photos | Batch confirmation + iOS Recently Deleted (30-day recovery) |
| API costs spike | On-device pre-filtering, response caching, per-user rate limits in Worker |
| App Store rejection over privacy | Privacy manifest in app, privacy-first onboarding, full local-only fallback mode |
| iOS tightens Files access | Photos is the core; files are bonus tier |
| Claude API outage | Fall back to local-only Vision categorization, queue API calls for retry |
| Network offline | Queue all analysis requests, allow swipe-only mode without AI suggestions |
| Backend abuse | KV-backed rate limit per user_id with daily cap matching tier |
