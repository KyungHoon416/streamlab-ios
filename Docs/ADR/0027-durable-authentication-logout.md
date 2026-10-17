# ADR 0027 — Durable authentication logout intent

Date: 2026-10-17
Status: Implemented; Mac execution pending

## Context

ADR 0026 passed 170 Core tests on Mac. Its generation grant blocked late refresh
writes in process, but a failed Keychain deletion could leave credentials restorable
after restart. Existing AccountLocalData already uses marker-before-cleanup for domain
journals. Keep that ordering for auth without putting MainActor domain cleanup inside
the Keychain actor or writing credentials to disk.

## Decision

KeychainTokenStore owns LogoutMarkers, a synchronous metadata helper. Default storage
is Application Support/StreamLab/AuthSignedOut; callers may provide a stable custom
logoutDirectory. A SHA256 of service + NUL + account scopes filenames. Scope validation
excludes NUL. Contents are only signed-out-v1, never credentials or raw account names.

Logout revokes the in-process grant, atomically writes the marker, then deletes the
Keychain item. The marker remains after successful cleanup. Public read and restore
refuse to return credentials while it exists; regular save cannot bypass it. Each
marker read validates the parent directory so inaccessible storage fails closed.
Malformed marker data throws, rather than being interpreted as no logout intent.

After recreation, retryPendingLogout(account:) deletes only if the durable marker
exists, and retains that marker. It is safe to repeat and is a no-op for a signed-in
account without a marker. A newer explicit sign-in cannot be deleted by an old session
logout callback because its generation no longer matches.

Explicit signIn(tokens,account:) is called only after authentication succeeds. It
revokes old grants, writes/retains the marker, writes the new token pair to Keychain,
and only then removes the marker. If interrupted between these steps, restoration
remains blocked. A failed write or marker removal is reported, not a successful login.
The caller can retry explicit sign-in. Invalid token input changes neither credential
nor marker state. AuthenticationSession.restore is still separate; no app login UI is
added in this change.

## Boundaries

Use one shared store per service and keep the same marker directory across launches.
A second concurrent actor/process is not synchronized; app extensions/shared access
would require a separate coordination design. Tests recreate a store sequentially to
model restart; they do not terminate a real app process.

If the marker itself cannot be written (disk full, filesystem protection/permission),
logout returns failure and the in-process session remains invalidated. Restart safety
cannot be guaranteed for an intent that never reached disk. Do not report persistent
logout success. Atomic file replacement addresses process interruption, not a promised
fsync/power-loss transaction spanning filesystem and Keychain. The APIs remain outside
the app's demo login/profile flow pending later integration.

The marker has no secrets. Removing app data or an external actor deleting the marker
is outside this recovery guarantee. iOS file protection/locked-device testing remains
separate. Keychain uses WhenUnlockedThisDeviceOnly as before.

## Validation

Seven tests use real temporary marker files and the existing injected Keychain backend:

- Delete failure, store recreation, hidden surviving credential, retry and marker retention.
- Explicit sign-in and stale logout/write rejection.
- Failed explicit sign-in retains the marker and blocks restore.
- Marker-only state models interruption before Keychain deletion.
- Corrupt marker blocks restore without consulting Keychain.
- A regular file in place of the marker directory causes failure; retry after repair works.
- Service/account isolation and token-free metadata.

The existing persisted-authentication suite now expects a durable signed-out restore
to return nil. check-durable-auth-logout-mac.sh requires both policy suites, the existing
Keychain suites, and real macOS Keychain dummy-item cleanup. Swift execution is pending.
