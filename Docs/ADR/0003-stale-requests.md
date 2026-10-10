# ADR-0003 — Cancel and fence stale searches

Status: Accepted for Phase 1

Context: Fast repeated queries and profile changes can produce responses out of order. Cancellation alone does not guarantee that a response has not raced to completion.

Decision: `SearchViewModel` cancels its previous Task, increments a monotonically increasing request generation and only commits results when the generation still matches. `HomeViewModel` uses the same generation-fencing principle.

Consequences: Unit tests cover repository pagination but true UI lifecycle races must be verified on macOS/iOS before Phase 1 is signed off. Add an injectable fake clock and mock transport in Phase 2.
