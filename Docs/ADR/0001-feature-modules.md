# ADR-0001 — Use SwiftPM modules and explicit repository contracts

Status: Accepted for Phase 1

Context: The challenge requires replacement-friendly network, storage and player layers and testable Swift 6 concurrency. A single SwiftUI target would mix concerns and make future player and sync replacement harder.

Decision: `StreamLabDomain` contains portable data contracts. `StreamLabCatalogData` is an `actor` implementation of `CatalogRepository`. UI feature modules depend only on protocol types, domain and design system. `App` owns dependency composition.

Consequences: Extra package manifests and boilerplate, but pure core can be compiled/tested independently from iOS. HLS playback, sync and download can be introduced without rewriting UI type contracts.
