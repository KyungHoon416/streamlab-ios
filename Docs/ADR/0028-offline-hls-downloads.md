# 0028 — Profile-scoped native HLS downloads

## Context

The existing bundled MP4 is an offline fixture, not a download. Add an explicit
Apple HLS sample download in Detail, using AVAssetDownloadURLSession and an iOS
18+ AVAssetDownloadConfiguration/willDownloadTo path. Never present the sample as
the catalog title's commercial media.

## Ownership and persistence

- A process-wide main-actor owner reconnects to a stable background session.
- A separate atomic JSON journal records account/profile/title, task UUID, state,
  relative system package path, size, pin and last-use date. No token is stored.
- Record before resuming a native task. On launch, reconcile against OS tasks;
  suspended tasks resume after a journal-before-resume crash;
  missing tasks become retryable failures, and missing files are not offered as
  successfully downloaded media. Corrupt journals fail closed without overwriting.
- Native package URLs stay where AVFoundation creates them. The iOS 27 simulator
  supplies a `/.nofollow/` alias; canonicalize that callback alias and still require
  containment in the current app home. Cover both alias and escape cases in Core.
  Validate relative
  paths inside the current app container; never move or edit package contents.
- A narrowly scoped UIApplicationDelegate bridge forwards background-session
  completion. SwiftUI continues to own all scenes and screens.

## Quota and deletion

- Two active/cancelling transfers at most; other requests remain queued.
- Budget: 1,000,000,000 bytes. Reserve 500,000,000 bytes per active sample download.
  Completed files count actual allocated bytes. LRU evicts only completed,
  unpinned, non-playing assets. Pins protect against the app's eviction, not OS
  purging. This is a conservative sample policy, not estimated production bitrate.
- Require reservation plus 50 MB available device space before starting. Monitor
  reported transfer bytes and available space during progress callbacks. Verify
  actual completed package size and reject oversized or non-offline-playable files.
- OS writes and callbacks are asynchronous: this is not an instantaneous hard
  filesystem quota. Real low-disk/background behavior needs device validation.
- Cancellation persists a removing tombstone until the OS task completes, then
  deletes the package. A failed deletion retains a record for retry/accounting.
- Playback holds a lease so eviction/deletion cannot remove an in-use package.
- Logout persists account revocation before cancelling/deleting; it waits for
  cancellation cleanup with a bounded timeout and retries from its existing
  durable logout path if interrupted. A late callback cannot reactivate the account.

## Playback and UI

Detail offers progress, pin, delete and explicit downloaded-sample playback.
The player resolves the file only for the active account/profile after the normal
Repository authorization check. Missing files fail; no silent online fallback.
Downloaded and online versions share the same sample progress identity.
Native audio/subtitle choices are filtered to AVAssetCache's offline options.
Downloads use Wi-Fi only. DRM and real licensed catalog media are out of scope.

## Validation

Eight Core tests cover exact budget, LRU, pinned/playing exclusions, concurrent
reservations, overflow, path traversal and record persistence. The native opt-in
UI test checks download, pin, relaunch, local playback and deletion. Use
`scripts/check-downloads-mac.sh`; a skip, failed transfer, or missing completion
must not count as a pass. Refer to the latest PHASE2_REPORT for executed results.

Device-only follow-up: airplane mode after completion, OS background wakeup,
force-quit/relaunch, real low disk, simultaneous network transfers, profile switches
and logout during a transfer. No claim of completed DRM or full C1 validation.

Sources: Apple AVFoundation offline playback and storage documentation;
AVAssetDownloadTask/AVAssetCache SDK declarations in Xcode 27.
