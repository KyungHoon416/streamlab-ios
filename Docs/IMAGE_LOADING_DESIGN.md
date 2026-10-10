# Future asynchronous artwork loading (proposal, not implemented)

Phase 1 draws local SF Symbols over deterministic gradients. No image HTTP requests occur. Collection/table reuse limits view allocation, but does not prove measured scroll or memory performance.

Introduce an `ImageDataLoading: Sendable` protocol returning `Data` asynchronously. An actor-based implementation should own URLSession, an in-flight task table and a byte-budgeted memory cache. Keys include resource URL + pixel size + account/profile/authorization scope when images are restricted. Validate status, content type and maximum response bytes before decode. Decode/downsample on a bounded worker away from the main actor; create/assign UIKit views on MainActor.

Each reusable cell owns a cancellation handle plus a represented-title ID/generation. `prepareForReuse` cancels its subscription, resets artwork, and increments generation. Completion checks identity and generation before assigning the image. Collection prefetching subscribes ahead of visibility; cancellation unsubscribes. Shared requests use subscriber reference counting so cancelling one cell does not abort another cell's fetch.

On profile switch cancel all profile-scoped subscriptions and purge restricted cache entries before constructing the next profile's UI. Handle memory warnings by dropping decoded artwork; cap concurrent decode work. Errors show offline placeholders and an explicit retry path. Never cache authorization headers or signed URLs in logs.

Required future tests: response after cell reuse; simultaneous subscribers then one cancellation; profile switch during decode; repeated URLs with different target sizes; oversized/invalid payload; memory warning; bounded cache eviction. Measure scroll p50/p95, allocations and retained objects in Instruments before claiming success.
