# SwipeClean -- App Store Connect Copy

All text below is ready to paste into App Store Connect.
Character counts noted where Apple enforces limits.

---

## App Information

**Bundle ID:** app.swipeclean
**SKU:** swipeclean-ios-1
**Primary Category:** Utilities
**Secondary Category:** Productivity

---

## Metadata (English -- US)

### Name
```
SwipeClean
```
(10 chars -- limit 30)

### Subtitle
```
Clean your photo library fast
```
(29 chars -- limit 30)

### Promotional Text
*(Updateable any time without a new review -- use for seasonal hooks)*
```
Your photo library is probably full of blurry shots, duplicates, and screenshots you forgot about. SwipeClean finds them and lets you swipe them away in seconds.
```
(163 chars -- limit 170)

### Keywords
*(Comma-separated, no spaces after commas, limit 100 chars)*
```
photo cleaner,duplicate photos,declutter,organizer,storage cleaner,AI photo,blur,screenshots,cleanup
```
(100 chars -- exact limit)

### Description
*(Limit 4,000 chars. Current: ~2,850)*

```
SwipeClean turns photo cleanup from a chore into a satisfying game.

Swipe right to keep. Swipe left to delete. Claude AI does the thinking so you can move fast.

-- HOW IT WORKS --

SwipeClean scans your photo library and groups your photos into smart categories. Then you swipe through them one by one -- keep what you love, toss what you don't, skip when you're unsure.

Right swipe -- Keep
Left swipe -- Delete
Up swipe -- Skip for now
Tap -- Inspect full size with pinch-to-zoom
Long press -- See AI reasoning

Every deletion goes to Recently Deleted first. You have 30 days to recover anything.

-- SMART CATEGORIES --

Duplicates -- Finds near-identical photos using on-device visual matching. Burst shots, slight crops, and accidental rephotos all caught.

Blurry -- Flags photos that didn't quite focus so you can stop keeping them out of guilt.

Screenshots -- Surface all your screenshots at once. Most of them you saved for five seconds of reference you already used.

Large Files -- The videos and photos eating the most storage, ranked by size.

Old & Untouched -- Photos you haven't looked at in over two years. Some are worth keeping. Most aren't.

Receipts & Documents -- Text-heavy photos you may have already scanned or no longer need.

Surprise Me -- A smart shuffle that surfaces high-value cleanup opportunities first.

-- AI THAT ACTUALLY HELPS --

SwipeClean uses Claude to analyze each photo and give you a plain-English reason to keep or delete it. You get album filing suggestions, duplicate grouping explanations, and category labels -- without having to think.

-- YOUR PRIVACY, BY DESIGN --

On-device first. Duplicate detection, blur analysis, and screenshot identification all happen locally. Nothing leaves your phone for those checks.

Thumbnails only. When AI analysis runs, SwipeClean sends a small compressed thumbnail -- maximum 512 pixels, JPEG quality 70%. Originals never leave your device.

Faces blurred by default. Thumbnails sent for AI analysis have faces blurred automatically. You can opt in to face-aware analysis in Settings.

Location stripped by default. GPS metadata is removed from all thumbnails before upload. You can opt in to location-aware album naming in Settings.

No storage on our end. The backend proxy is stateless. Your thumbnails are processed and immediately discarded.

-- SWIPECLEAN PRO --

Unlimited swipes every day
AI album filing suggestions
Advanced duplicate grouping
Files app integration
Priority API access

Try free: 50 swipes per day, no card required.

Upgrade options:
- Pro Monthly ($2.99/month) -- Cancel any time
- Pro Yearly ($19.99/year) -- Save over 40% vs monthly
- Big Cleanup Pack ($4.99) -- Unlimited for 7 days, one-time, no subscription

Subscriptions auto-renew unless cancelled at least 24 hours before the renewal date. Manage in Apple ID Settings.
```

### Support URL
```
https://shizzoobies.github.io/IOS-Cleanup-App/support
```

### Privacy Policy URL
```
https://shizzoobies.github.io/IOS-Cleanup-App/privacy
```

### Marketing URL *(optional -- leave blank for now)*
```

```

---

## App Store Review Information

### Review Notes
*(Paste this into the "Notes" field on the App Review page)*

```
Thank you for reviewing SwipeClean.

PHOTO LIBRARY ACCESS
The app requires Photos permission to function. Please grant Full Access when prompted. On the simulator you may need to add a few test photos via the Photos app first.

IN-APP PURCHASES (STOREKIT SANDBOX)
The three in-app products can be tested using a Sandbox Apple ID:
- SwipeClean Pro Monthly: app.swipeclean.pro.monthly ($2.99/mo)
- SwipeClean Pro Yearly:  app.swipeclean.pro.yearly ($19.99/yr)
- Big Cleanup Pack:       app.swipeclean.bigcleanup ($4.99 one-time)

To reach the paywall: tap "Upgrade" in the toolbar on the home screen, OR swipe 50 photos (the free daily limit).

SWIPE LIMIT
Free users get 50 swipes per day. The paywall appears automatically at swipe 51. There is no hidden content -- all categories are visible to free users, just gated at 50 swipes.

DELETION SAFETY
All deletions go to the iOS Recently Deleted album. Nothing is permanently erased through the app. The batch-delete confirmation sheet appears every 50 deletions.

AI ANALYSIS
AI-powered summaries require a network connection. The backend is live at https://swipeclean-proxy.tgqhg6kf4g.workers.dev. If the network is unavailable, the app degrades gracefully -- cards still show with on-device category labels, just without the AI summary text.

CONTACT
asoalexander@gmail.com
```

### Sign-in Required?
```
No -- the app does not require an account.
```

---

## TestFlight -- What to Test

*(Paste into TestFlight > Test Information > What to Test)*

```
Thanks for beta testing SwipeClean! Here's what we'd love your feedback on:

SETUP
1. Open the app and complete the 4-screen onboarding.
2. Grant Full Access to your photo library when prompted.
3. Wait for the library scan to complete -- you'll see category cards appear with photo counts.

CORE SWIPE FLOW
- Tap any category and swipe through photos.
- Right swipe = keep, left swipe = delete, up swipe = skip.
- Tap a card to inspect the photo full-size (pinch to zoom).
- Long-press a card to see the AI's reasoning.
- Try the undo button (curved arrow) -- it should restore the last card.

THINGS TO FOCUS ON
- Do the category counts look accurate for your library?
- Does the AI summary on each card make sense for the photo?
- Does the album suggestion seem reasonable?
- After 50 swipes, does the paywall appear smoothly?
- Does the batch-delete confirmation sheet appear and work correctly?
- After confirming deletion, do the photos appear in Recently Deleted in the Photos app?
- Try Settings (gear icon) -- do the privacy toggles work?

HAPTICS
- Swipe on a real device to feel the haptic feedback (light buzz for keep, strong buzz for delete, medium for skip).
- Simulator won't vibrate -- this needs a physical iPhone.

KNOWN LIMITATIONS IN THIS BUILD
- Files app cleanup (the "Clean up Files" card) is a stub -- it opens but has no content yet. That's intentional for this beta.
- The AI summary takes 1-3 seconds to load per card. This is expected -- it's a live API call.
- The paywall products load from the live App Store sandbox. Use a Sandbox Apple ID to test purchases without being charged.

BUGS / FEEDBACK
Please report crashes, incorrect categorization, or anything that feels off to: asoalexander@gmail.com

Thank you -- every piece of feedback directly shapes the 1.0 release.
```

---

## Subscription Group Setup (App Store Connect)

When creating your In-App Purchases, set up exactly as follows:

### Subscription Group
**Group Name:** Pro

### Product 1 -- Pro Monthly
| Field | Value |
|---|---|
| Reference Name | Pro Monthly |
| Product ID | app.swipeclean.pro.monthly |
| Subscription Duration | 1 Month |
| Price | $2.99 USD (Tier 3) |
| Display Name (en-US) | SwipeClean Pro Monthly |
| Description (en-US) | Unlimited swipes, AI album filing, and advanced duplicate grouping. |

### Product 2 -- Pro Yearly
| Field | Value |
|---|---|
| Reference Name | Pro Yearly |
| Product ID | app.swipeclean.pro.yearly |
| Subscription Duration | 1 Year |
| Price | $19.99 USD (Tier 20) |
| Display Name (en-US) | SwipeClean Pro Yearly |
| Description (en-US) | Unlimited swipes, AI album filing, and advanced duplicate grouping. |

### Product 3 -- Big Cleanup Pack (Non-Renewing Subscription)
| Field | Value |
|---|---|
| Reference Name | Big Cleanup Pack |
| Product ID | app.swipeclean.bigcleanup |
| Type | Non-Renewing Subscription |
| Duration | 7 days (enforced in-app) |
| Price | $4.99 USD (Tier 5) |
| Display Name (en-US) | Big Cleanup Pack |
| Description (en-US) | Unlimited swipes for 7 days. One-time purchase, no subscription. |

---

## Screenshots Needed

Apple requires at least one screenshot per device class you support.
Minimum required set: **6.9" (iPhone 16 Pro Max)** + **6.5" (iPhone 14 Plus or 11 Pro Max)**

Recommended shots (take in simulator or on device):
1. Home screen -- category grid fully loaded with real photo counts
2. Swipe deck in action -- card visible with AI summary overlay
3. Swipe hint visible -- card dragged right with green "KEEP" badge
4. Inspect view -- full-size photo with info tab open
5. Paywall -- all three products showing prices
6. Privacy settings screen

To take simulator screenshots: **Device > Screenshot** or **Cmd+S** in the simulator window.
Save as PNG, do not resize -- Apple accepts the simulator's native resolution.

---

## Export Compliance

When submitting, Apple asks about encryption:

**Does your app use encryption?** -- Select **Yes**
**Is your app exempt from export compliance?** -- Select **Yes**

Reason: The app uses standard HTTPS (TLS) provided by the iOS networking stack only. No custom or proprietary encryption is implemented. This qualifies for the ECCN 5D992.c exemption.
