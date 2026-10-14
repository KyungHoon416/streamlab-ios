# ADR 0014 — Persist audio language and description role

Status: accepted; Mac validation pending.

Language alone cannot distinguish English from English DVS. Store an optional
AudioRole beside audio language in the existing profile-scoped v1 JSON record.
Synthesized Codable decodes a missing optional role as nil, preserving old settings.
Automatic selection clears the explicit role; unsupported audio off is ignored.

AVFoundation hasMediaCharacteristic(.describesVideoForAccessibility) supplies the
role. Do not infer it from translated names or persist transient option indices.
Resolve the best language using existing rules, then prefer the requested role
within that matched language. If absent use that language's available track; if
language is absent use the source default. Neither fallback rewrites preferences.

Same-role tracks (e.g. multiple commentary tracks) remain indistinguishable. This
is a semantic DVS preference, not an exact rendition/codec identifier. Unknown
language tracks remain session-only. Existing cancellation/generation checks apply.

Tests cover legacy decoding, persistence across store instances, profile isolation,
automatic reset, order independence, missing language/role and return to supported
media. Core tests cannot prove AVPlayer output; manual real-HLS listening is required.

Reference: https://developer.apple.com/documentation/avfoundation/avmediaselectionoption
