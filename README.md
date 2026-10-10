# StreamLab — UIKit + Storyboard Phase 1

> Unofficial iOS engineering practice project, not affiliated with Netflix.

**UI migration:** UIKit and Main.storyboard replace the original SwiftUI interface. This intentionally **deviates from the challenge document**, which specifies SwiftUI + AVFoundation. Swift 6 and iOS 18+ remain.

## Features
- Four Storyboard scenes: Profile, Home, Search, Detail (each builds its contents in UIKit code)
- Three Mock profiles (Alex, Jamie, Kids)
- 2,000 local catalog entries, five curated rails and per-profile continue watching
- Repository-level kids access checks, cursor pagination, async cancellation and stale-response fencing
- HLS playback and downloads are not implemented (future phases)

## Setup on Mac
```sh
brew install xcodegen
./scripts/bootstrap-mac.sh
open StreamLab.xcodeproj
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
cd Packages/StreamLabCore && swift test
```

Swift 8.0 is **not assumed to be available**. Verify the compiler installed with Xcode via `swift --version`. This repository retains Swift 6 language settings.

## Validation
Changes were committed through GitHub without direct Mac/Xcode access; Xcode build and UI runtime remain **NOT TESTED**. Run on a simulator and report errors before Phase 2. The project keeps prior Core unit tests.

## Technical design
Main.storyboard owns ViewController scene definitions and identifiers. AppDelegate/SceneDelegate own app/session navigation. UIKit ViewControllers build layouts and render models, while the SwiftPM StreamLabCore maintains independent models and a Mock repository. UI no longer depends on StreamLabUI Swift Package.
