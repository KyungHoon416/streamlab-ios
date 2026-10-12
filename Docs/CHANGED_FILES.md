# SwiftUI migration changed files

Base: a2ecc89. Presentation migration; Core fixture and test logic unchanged.

- App/Application/StreamLabApp.swift, App/Scene/AppRootView.swift
- App/Configuration/Info.plist, StreamLab.xcodeproj project/scheme
- Packages/StreamLabUI/Package.swift, DesignSystem/Theme
- ProfileSelectionView, HomeView, SearchView, DetailView
- CatalogSession, CatalogScreenModel
- StreamLabUITests (11 definitions)
- validate-project.py, test-project-parser.py, summarize-runtime.py, verify-mac.sh
- README, specification, report, manual QA, ADR-0006, historical annotations

Deleted: AppDelegate, SceneDelegate, four ViewControllers/Storyboards, PosterCell, RailHeader.
Historical implementation remains in Git.
