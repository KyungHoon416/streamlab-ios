# ADR 0013 — Profile-scoped subtitle and audio language preferences

Status: implemented; Mac build/runtime validation pending.

## Decision

Use a MainActor `PlaybackLanguageStore` in each immutable-profile `CatalogSession`.
Store a versioned Codable preference record in UserDefaults, with a separately
base64-encoded profile ID. This is small settings persistence, not the future
download database. Defaults are subtitles off and audio automatic.

Persist BCP 47 language tags, never AVFoundation option indices or display names.
Match normalized exact tags first, then a generic base language. Generic preferences
may match a regional track; explicit script/region preferences do not substitute
another explicit script/region. Missing languages use the manifest default option,
then subtitles off where allowed or the first playable required/audio option.
Fallback never overwrites the preferred language. Mandatory subtitles cannot be disabled.
Tracks without language metadata apply only to the current item without changing
stored preferences. Alternate renditions with the same language use deterministic
manifest order; preserving SDH/audio-description rendition identity is future work.

The player reads preferences on every item load, including episode transitions.
Separate cancellable audible/legible tasks check generation, item identity and session
activity before applying results. Explicit user selection is persisted synchronously.
AVPlayer automatic selection criteria are disabled so they do not overwrite app selection.
UI offers subtitle and audio choices in one accessible sheet. Bundled demos are silent;
real alternative audio requires HLS media that actually provides playable audio renditions.

## Validation

Core tests cover persistence, profile separation, off, exact/regional matching,
missing language fallback, preserved preference, required tracks and empty groups.
UI tests cover subtitle seeking/restoration, next episode, process relaunch,
off persistence and another profile's independent default.
Real HLS audible-track switching/listening is explicitly NOT TESTED by offline tests.

Sources: Apple AVMediaSelectionOption (`extendedLanguageTag`, `isPlayable`),
AVMediaSelectionGroup (`defaultOption`, `allowsEmptySelection`), AVPlayerItem.select.
https://developer.apple.com/documentation/avfoundation/avmediaselectionoption
