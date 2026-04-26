# SwipeClean — Product Spec (v1)

## Concept

A Tinder-style decluttering app for iPhone that walks users through their photos and files one at a time, with Claude as an intelligent sorting assistant that recognizes content, groups duplicates, and suggests where things should live.

## Target user

- iPhone owner with 5,000+ photos and a chaotic camera roll
- Has tried "delete duplicates" apps and bounced off the tedium
- Trusts AI assistance for tagging and filing but is privacy-conscious about photos
- Willing to pay $4.99/mo if it actually works

## Core user flow

1. **Onboarding.** Request Photos library access (full), Files access via document picker, optional iCloud Drive scope. Privacy explainer: originals never leave the device, only thumbnails go to the AI for analysis, faces are blurred by default.

2. **Smart queue.** App pre-groups items before the user starts swiping:
   - Exact and near-duplicates (perceptual hash on-device)
   - Screenshots
   - Blurry photos
   - Large or old files
   - Receipts and documents (text-detected)
   User picks a category to tackle, or "Surprise me."

3. **Swipe session.** One item at a time, full-screen, with AI-generated context (e.g., "Screenshot from Safari, March 2023, looks like a recipe").
   - **Swipe right → Keep.** Claude asks: "Want me to file this in Recipes, or pick somewhere yourself?" User accepts the AI suggestion, picks an album/folder, or skips filing.
   - **Swipe left → Delete.** Item goes to a pending-deletion tray, not deleted immediately.
   - **Swipe up → Skip / decide later.**
   - **Tap → Inspect mode** (full-resolution view, metadata, similar items, AI rationale).
   - **Long press → Why grouped panel** (perceptual hash group, similar files).

4. **Batch confirmation.** Every 50 swipes or at end of session, iOS shows the native delete confirmation for everything in the trash tray. One tap, everything's gone (to Recently Deleted).

5. **Undo.** Last 10 actions reversible during a session.

## Inspect mode

For photos/videos:
- Full-resolution view with pinch-to-zoom and pan
- Video scrubber for video assets
- Metadata: date, location (with mini-map), camera, file size, dimensions
- "Similar items" carousel showing other photos Claude grouped with this one
- Claude's analysis: detected content, suggested album, why it might be a duplicate

For files:
- Native QuickLook preview
- File path, size, last modified, last opened
- Claude's content summary
- "Similar files" if Claude found content overlap

Exit inspect: tap X, swipe down, or swipe left/right directly to act on it.

## Privacy story

Three tiers, all surfaced clearly in onboarding:

1. **On-device only:** duplicate detection, perceptual hashing, blur detection, file size analysis, screenshot flagging. Uses Apple Vision and PhotoKit. Never leaves the phone.

2. **Thumbnails to Claude:** for categorization and filing suggestions, the app sends a downsampled (max 512px long edge), face-blurred-by-default, EXIF-stripped JPEG plus minimal metadata. Originals stay local.

3. **User opt-in for sensitive content:** faces blurred by default, location stripped by default. Users can opt into face-aware and location-aware analysis for richer suggestions.

## v1 scope

**In:**
- Photos and videos from the camera roll
- Files via Files app integration (Documents, Downloads, iCloud Drive)
- AI categorization and album suggestions
- Duplicate and near-duplicate detection (on-device)
- Swipe interface with batch deletion
- Inspect mode
- Album creation and filing
- Undo within session
- Free tier with daily swipe limit
- Pro tier with unlimited swipes and AI filing

**Out (v2 or later):**
- Cloud storage integrations (Dropbox, Google Drive, OneDrive)
- Family sharing or multi-device sync
- Scheduled cleanup reminders
- Custom rules ("auto-delete screenshots older than 90 days")
- iPad-optimized layout
- macOS catalyst version

## Monetization

- **Free:** 50 swipes/day, basic duplicate detection, on-device categorization only, no AI filing
- **Pro:** $4.99/mo or $29.99/yr. Unlimited swipes, AI filing, file scope, priority API access, advanced grouping
- **Big Cleanup pack:** $9.99 one-time, unlimited for 7 days. Aimed at first-time deep cleans.

## Success metrics

- Activation: percent of installs that complete first 50 swipes
- Retention: D7 and D30 return rates
- Conversion: free → Pro within 14 days
- Cleanup volume: median photos cleared per active user per week
- AI filing acceptance rate: percent of Claude album suggestions accepted as-is (target: 60%+)
