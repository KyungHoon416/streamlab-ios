# ADR 0025 — Account-scoped Keychain token storage

Status: implemented; Swift/Mac Keychain execution pending.

## Decision

KeychainTokenStore serializes synchronous Security framework calls in an actor. Each service/account
pair is one generic-password item containing an access/refresh token pair. Use opaque account IDs,
not email addresses. No caller can pass an empty scope or issue a broad deletion. The caller should
share one actor per namespace; independent concurrent writers are last-writer-wins, not revision-aware.

Both tokens update in one SecItemUpdate operation. On not-found, insert; on duplicate insert, retry
update once. Never delete the old item before writing a replacement. A missing read returns nil;
locked/denied/entitlement failures throw an OSStatus-only error. Invalid payloads throw corruptItem and
are not silently removed. No fallback to UserDefaults/files. Delete is idempotent only for not-found.

Items set synchronizable=false and WhenUnlockedThisDeviceOnly. This chooses foreground-only iOS
availability and prevents migration to a different device; background refresh while locked must fail
and defer, not weaken protection automatically. Platform lock-state behavior needs real iOS validation.
Apple reference: https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly
The macOS package test uses the platform's default Keychain implementation and does not establish iOS
Data Protection, lock-state, backup or entitlement behavior.

AccountTokens descriptions redact both values. Token values and raw Security dictionaries are never
logged. Tokens must remain in memory for authorization/encoding; this is not a secure-memory/zeroization
guarantee. Cancellation is checked before a synchronous operation; once a SecItem call has committed,
cancellation cannot undo it. The caller must treat refresh persistence and logout ordering explicitly.

## Integration boundary

This store is not yet wired into AuthenticationSession or CatalogAccount. Before that integration,
add a session-generation guard around refresh persistence so a late refresh cannot recreate a logged-out
account. Invalidate the in-memory session, cancel tasks, delete exact stored credentials, and surface
failed cleanup rather than pretending success. Refresh-token rotation and Keychain failures must be
handled before publishing a new session. No real user credentials are required for these tests.

## Validation

Six injected-backend tests cover account isolation/update/delete, duplicate-insert recovery, locked/
authentication/entitlement failures, corrupt payloads, invalid input/redaction, and pre-cancelled writes.
The lock-protected test double models status returns, not platform security guarantees.

One opt-in system integration test writes dummy tokens under a UUID service, reopens a store, updates,
checks account isolation, deletes the two exact items and checks absence. It never enumerates existing
credentials. Errors attempt scoped cleanup and report cleanup failure. Interrupting the process may
leave dummy entries under `com.streamlab.tests.tokens.<UUID>`; no blanket cleanup is performed.

Run `bash scripts/check-keychain-mac.sh`. The script enables the system test and requires both suites
and the lifecycle marker. Generic Core runs skip system access. If macOS requests Keychain access,
inspect the requesting StreamLab test process; authentication/permission errors remain failures.
Collect RESULTS.txt, environment.txt, core.log. No iOS lock-state claim follows from Mac success.
