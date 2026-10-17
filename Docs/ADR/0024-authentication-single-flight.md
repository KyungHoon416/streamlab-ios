# ADR 0024 — Account-session authentication refresh single-flight

Status: implemented opt-in Core boundary; Mac execution pending.

## Decision

Each signed-in account session owns one AuthenticationSession actor. It holds an in-memory token
lease and version. A new explicit sign-in creates a new actor; never reuse an actor across accounts.
AuthenticatedHTTPClient is an optional execute function for HTTPMutationTransport. It accepts only
HTTPS requests to its configured origin, overwrites Authorization, and rejects body streams because
replay requires an immutable body. Its default transport rejects redirects via the existing loader.
An injected transport must preserve that policy. Refresh uses a separate transport, not this client.

On 401, requests with the same rejected lease join one refresh. A late old-token 401 reuses the already
renewed lease. Each request is replayed at most once with unchanged body/idempotency headers; a second
401 is terminal. Refresh failure (including a simulated 500) is latched for the session, so late arrivals
cannot start repeated refreshes. Recovery requires explicit session replacement/sign-in.

Waiters use individual continuations. Cancelling one removes only that waiter, without cancelling the
shared operation. A default 15-second deadline releases waiters even if the refresh implementation
ignores cancellation. Refresh and deadline tasks are cancelled after completion; flight identity rejects
late results. A non-cooperative provider may keep its own work alive, but cannot publish after timeout
or invalidation. Refresh providers must implement bounded network timeouts and cancellation themselves.
An injected deadline should return when elapsed; unexpected non-cancellation failure also expires it.

invalidate() clears the token, cancels refresh/deadline tasks, and fails all refresh waiters immediately.
Requests already executing are checked after transport return and cannot publish a response after
invalidation. Invalidation does not itself abort every underlying request socket; callers still own
request Task cancellation. The actor protects account-session scope; profile isolation remains the
responsibility of the existing profile lifecycle/generation checks.

## Security and scope

No tokens are written to disk or logged. Lease descriptions are redacted; refresh errors are normalized
without retaining provider error payloads. Credentials are checked for a nonempty bearer-safe character
set before header construction. Keychain, refresh HTTP contract, login UI and CatalogAccount logout
wiring remain separate work. The app continues using its existing Mock flow; this is not production
authentication completion or completion of all C2/B3 requirements.

## Validation

Nine tests exercise eight overlapping 401 requests/one refresh, eight waiters failing on refresh 500,
late 401 reuse, individual cancellation, logout during refresh, timeout with a non-cooperative provider,
second-401 termination, logout during request execution, and credential/origin rejection.
Barriers hold the provider until overlap is observed. A short bounded poll only synchronizes test setup;
deadline behavior is injected explicitly rather than measured with wall-clock sleeps. HTTP responses
and refresh are injected, not a live auth server. The refresh-500 case models the provider throwing on
HTTP 500; actual status parsing of a refresh endpoint is not implemented here.
Run `bash scripts/check-auth-single-flight-mac.sh`; inspect RESULTS.txt/environment.txt/core.log.
