> Current UI: SwiftUI (ADR-0006). Network loading remains proposed. Apply identity/cancellation to view tasks; earlier UIKit cell examples are historical context.

# ADR-0005 — Future asynchronous image loading

Status: Proposed, not implemented. Phase 1 uses local artwork.
User-requested UIKit cell reuse is implemented; no remote-image behavior is claimed tested.

Design:
- Inject an ImageDataLoading: Sendable boundary returning immutable Data from an async throwing method. Keep UIKit image/view state on MainActor.
- Use an actor for URL/cache-key lookup and in-flight request coalescing. Include target pixel size and image version in the key; never use only a reusable cell's index path.
- Define bounded memory/disk budgets, eviction and memory-pressure handling before enabling cache persistence. Validate response type and size before decoding.
- Downsample off the main thread using ImageIO in an isolated decoding component. Transfer only explicitly safe immutable results across isolation boundaries; do not add unchecked Sendable to silence compiler errors.
- Each cell owns a cancellable consumer task and represented content ID/generation. On reuse/end-display cancel the consumer and clear its image. Before display, verify both identity and generation.
- Shared requests track active consumers; cancelling one cell must not cancel another cell's request. Cancel upstream when no consumers remain.
- Prefetch only a small bounded window; cancel prefetch as scrolling/profile context changes. Handle failures with a local placeholder and an explicit retry policy.
- Profile changes invalidate consumers. If later images are profile-authorized, partition caches and authorization by profile/session; public artwork can share cache only under an explicit public-data policy.

Required future tests: reversed completion/reuse, duplicate consumers with one cancelled, profile switch, invalid or oversized images, bounded cache eviction, decode performance, offline failure and memory-pressure behavior. No network image implementation or performance measurements are certified by this document.
