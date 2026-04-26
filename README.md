# SwipeClean

A Tinder-style decluttering app for iPhone, powered by Claude. Swipe right to keep, left to delete; Claude suggests where kept items should be filed.

## Repo layout

```
SwipeClean/
├── docs/                      # Spec, architecture, API contract, prompts
│   ├── PRODUCT_SPEC.md
│   ├── ARCHITECTURE.md
│   ├── API_CONTRACT.md
│   ├── CLAUDE_PROMPTS.md
│   └── BUILD_PLAN.md          # ← Start here for build order
├── ios/                       # SwiftUI app (iOS 17+)
│   └── SwipeClean/
│       ├── App/               # Entry point
│       ├── Models/            # Domain models (Asset, Decision, Session...)
│       ├── Views/             # SwiftUI views (SwipeDeck, InspectView...)
│       ├── ViewModels/        # @Observable view models
│       ├── Services/          # PhotoLibrary, FileAccess, ClaudeService
│       ├── Vision/            # On-device analysis (duplicates, blur, OCR)
│       ├── Persistence/       # SwiftData stack
│       └── Utilities/         # Helpers, extensions
├── backend/                   # Stateless proxy for the Anthropic API
│   ├── src/                   # Node/TypeScript Cloudflare Worker
│   ├── package.json
│   └── wrangler.toml
└── CLAUDE.md                  # Instructions for Claude Code (read this!)
```

## For the human

You're handing this to Claude Code to flesh out. Before you do:

1. Open the project in Xcode by creating a new Xcode project at `ios/` targeting iOS 17+, SwiftUI, SwiftData. Drag the existing `SwipeClean/` folder in.
2. Set up the backend with `cd backend && npm install`. You'll need a Cloudflare account (free tier is fine) and an Anthropic API key.
3. Tell Claude Code: "Read CLAUDE.md and docs/BUILD_PLAN.md, then start with Phase 1."

## For Claude Code

See `CLAUDE.md` at repo root.
