# ADR 0012: Explicit demo episode sequence
Status: Accepted for demo implementation; Xcode validation pending.

## Context
The catalog has no real episode manifest. Existing single-media and resume tests must retain their behavior.

## Decision
Expose three clearly labeled demo episodes in the source picker, reusing the bundled MP4 and SRT.
Each has a stable progressID; no fabricated catalog titles or relaxed kids permissions are introduced.
A pure Sendable countdown consumes monotonic elapsed time. The existing MainActor sample loop drives it, so no additional timer or unstructured task is required.
Completion can advance once per item. Cancel is sticky until seek/reload resets the item countdown.
Background, close, profile invalidation, and source changes cannot leave an independent countdown task running.
Every next-item load uses the existing generation guard, teardown and Repository authorization path.

## Tradeoffs
This proves the local AVPlayer sequence/control lifecycle, not a production season/episode backend.
Source switching resets subtitles; preferred language restoration remains separate work.
The three demo media payloads are identical, and source/episode labels distinguish them.
Final episode remains ended. Paused seeking to end does not initiate automatic playback.

## Validation
Three pure countdown tests and two UI scenarios cover deadline/once-only, cancellation/reset, invalid time, sequential transitions, final stop and manual advance.
Not executed on Xcode at authoring time. UI script: scripts/check-episodes-mac.sh.
