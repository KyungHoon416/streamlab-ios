# ADR-0004 — UIKit and Storyboard instead of SwiftUI

Status: Accepted, user instruction 2026-10-10. Supersedes SwiftUI/UI-tree references in ADRs 0001–0003.

The original exercise requests SwiftUI. The user explicitly requests a native UIKit app with editable Storyboards. Swift 6 and iOS 18 remain unchanged.

Each screen root is instantiated from its own SwiftPM resource storyboard using Bundle.module. Their Auto Layout constraints, root controls and IBOutlet connections are editable in Interface Builder. Navigation/tab composition and reusable catalog cells are implemented in Swift. There is no SwiftUI or UIHostingController.

UICollectionView compositional layout reuses visible cells and supports orthogonal horizontal rails; UITableView reuses search result cells with automatic row heights. These replace LazyHStack/LazyVStack. No custom animation is required; navigation honors Reduce Motion.

A portable MainActor CatalogStore is shared by UIKit and deterministic concurrency tests. Each screen owns a store; leaving a screen invalidates its request generation and cancels its Task. Profile switching invalidates root stores synchronously, replaces the root controller, and releases the old navigation tree. A weak task capture prevents a non-cooperative repository from retaining a store across await. Detail controllers own their stores; the coordinator does not accumulate popped detail stores.

Tests are written but have NOT been compiled or executed in this delivery environment. UIKit/IB connections require the actual Mac validation gate.
