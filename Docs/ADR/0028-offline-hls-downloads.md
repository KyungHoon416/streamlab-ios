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
  containment in the current app home. Physical iOS also supplied /private/var
  while NSHomeDirectory returned /var for the same container UUID. Normalize this
  exact Darwin alias for comparison after symlink resolution on both sides; retain
  the app-home URL for I/O. Do not strip arbitrary path components or accept other
  container IDs. Tests cover aliases, prefix lookalikes, and symlink escapes.
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

Detail and a dedicated Downloads tab share progress, pin, delete and explicit
downloaded-sample playback controls. The library lists only the active account
and profile, sorts by last use, and reports that profile’s saved bytes and count.
Playback from the library uses the same authorization, lease and orientation lifecycle
as Detail. Storage metadata remains atomic JSON; no SwiftData migration is involved.
The player resolves the file only for the active account/profile after the normal
Repository authorization check. Missing files fail; no silent online fallback.
Downloaded and online versions share the same sample progress identity.
Native audio/subtitle choices are filtered to AVAssetCache's offline options.
Downloads use Wi-Fi only. DRM and real licensed catalog media are out of scope.

## Validation

Eleven Core tests cover exact budget, LRU, pinned/playing exclusions, concurrent
reservations, overflow, path traversal and record persistence. The native opt-in
UI test checks download, pin, relaunch, library profile isolation, local playback
and deletion. A separate UI test checks the empty library at maximum text size. Use
`scripts/check-downloads-mac.sh`; a skip, failed transfer, or missing completion
must not count as a pass. Refer to the latest PHASE2_REPORT for executed results.

The user reported successful physical-device download and airplane-mode playback
with seeking after relaunch on 2026-10-20. This is user-reported runtime evidence.
Device-only follow-up: the new library UI, OS background wakeup,
real low disk, simultaneous network transfers, profile switches
and logout during a transfer. No claim of completed DRM or full C1 validation.

Sources: Apple AVFoundation offline playback and storage documentation;
AVAssetDownloadTask/AVAssetCache SDK declarations in Xcode 27.

## Completion notifications

Completion alerts are opt-in local UserNotifications requests, gated by real system
permission, saved complete records and background application state. A generic body
avoids account/profile/title disclosure on the lock screen. No push entitlement or
remote service is added. Main-actor notification coordination checks a revocation
epoch and record eligibility before/after async authorization and OS add calls.
Cancellation removes both pending and delivered requests. Logout revokes before its
first suspension, removes identifiers restored from the journal synchronously, then
purges surviving owned identifiers from the notification center. Native background
completion waits for outstanding notification work. No replay of old completed
records is triggered by launch. Notification UI presentation remains subject to OS
permissions, Focus and device settings.
