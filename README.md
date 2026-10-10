# StreamLab — Phase 1 iOS Starter

> Unofficial portfolio project. Not affiliated with Netflix or its recruitment process.

Swift 6, iOS 18+, SwiftUI, SwiftPM and XcodeGen. Phase 1 is a profile-aware catalog mock, not yet a streaming player.

## Run on Mac
```bash
brew install xcodegen
./scripts/bootstrap-mac.sh
open StreamLab.xcodeproj

# Or build without signing
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Tests
```bash
cd Packages/StreamLabCore
swift test
```

## Current Phase 1
- 3 profiles: Alex, Jamie and Kids
- 2,000 generated Mock content records, 5 recommendation rails
- Kids entitlement filtering at repository boundary, including details
- Cursor pagination, search cancellation, stale response fencing
- SwiftUI Home, Search and Detail. Playback button clearly says Phase 2.
- Three ADRs and testable domain boundaries

The bundled media metadata is fabricated and artwork uses SF Symbols and gradients. No Netflix videos or APIs are included. Native iOS simulator validation remains required after XcodeGen generation.

**Important:** The repository was initialized remotely with the Phase 1 starter snapshot. Local edits to StreamLabApp.swift (such as the blue test screen) are not automatically synchronized. To bring them back, commit on your Mac and push to this repository.

See Docs/PHASE1_SPEC.md and Docs/PHASE1_REPORT.md.
