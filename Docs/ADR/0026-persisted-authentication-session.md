# ADR 0026 — Keychain-backed authentication sessions

Date: 2026-10-17
Status: Implemented; Mac execution pending

## Decision

`AuthenticationSession.restore(account:store:refresh:deadline:)` restores an existing
Keychain account item. Missing credentials return nil; Keychain failures propagate.
Explicit sign-in must first save a validated AccountTokens pair. The app still uses
its existing demo account/profile flow; no login UI or production endpoint is added.

Refresh reads the current refresh token, calls the injected unauthenticated provider,
validates the returned pair and bearer syntax, checks cancellation, and saves both
credentials before returning the access token to the existing single-flight session.
Storage failure is normalized to refreshFailed for pending HTTP requests, which do
not replay with an unsaved token. The session latches that failure as before.

One shared KeychainTokenStore actor per service maintains an account generation grant.
Its grant check and synchronous Keychain write have no suspension point. Opening a
new session replaces the grant; old session writes and deletes cannot affect it.
The low-level public save/delete API is for setup/explicit credential management;
it must not be used by refresh providers to bypass session grant checks.

`logout()` invalidates in-memory state/cancels refresh immediately, then revokes the
store grant and deletes the exact account item. Cleanup is a detached operation so
cancelling the caller cannot silently skip deletion. A write already completed before
logout is followed by deletion; a queued late write sees cancellation or a revoked
or replaced grant. The underlying Keychain operation is synchronous and cannot be
interrupted midway. No token is published after session invalidation.

Deletion failure propagates to the caller. The grant stays revoked, restore is blocked
for that account in the same store, and retaining the session permits retrying logout.
A newer session's item is never deleted by an old session's logout retry. `invalidate()`
remains an in-memory operation for compatibility; callers of persisted sessions must
use `logout()` for credential deletion.

## Limits

Grants are process-local. Multiple independent stores/processes/extensions using the
same service are not coordinated. Use a single shared actor. If deletion fails and
the app terminates, the Keychain item may remain: durable logout tombstones and app
sign-in recovery policy are not implemented. Report deletion errors, do not treat
logout persistence as successful until deletion succeeds.

The refresh deadline includes storage scheduling. Cancellation blocks a late provider
from beginning a write. A synchronous write that has already begun may finish before
the timeout is processed, while the in-memory session rejects publication. A later
restore can use that valid saved pair; this is not an atomic transaction across actors.

## Validation

Eight deterministic integration-policy tests use the existing synchronous fake backend:
shared refresh persists before publish and restores; write failure; logout with late
uncancellable response and account isolation; delete failure/retry; replacement grant;
invalid bearer; refresh deadline with late response; cancelled logout caller.

`scripts/check-persisted-auth-mac.sh` runs all Core tests with warnings as errors and
strict concurrency, requires this suite and the Keychain suites, and also executes the
existing real macOS Keychain dummy-item lifecycle test. The new session-policy tests
use an injected backend; real iOS lock/entitlement behavior and app wiring remain pending.
