# Mutation HTTP contract — draft v1

This is a proposed contract for the opt-in `HTTPMutationTransport`, not evidence of a deployed backend.
The app continues using `MockMutationServer`. Backend URL, authentication/token refresh and production
routing are not configured. `scope` is a data partition, never proof of authorization; a future server
must authorize the authenticated caller for the requested account/profile.

## Requests and responses

The configured HTTPS base URL may contain a path (e.g. `/v1`), but no credentials, query or fragment.
All requests use POST, `Content-Type: application/json` and `Accept: application/json`.

| Endpoint | Request | Accepted response |
| --- | --- | --- |
| `/mutations` | JSONEncoder representation of `DurableMutation`, sorted keys; `Idempotency-Key` equals body UUID `id` | 200 with `{"id":"original UUID","revision":baseRevision+1}` |
| `/mutations` conflict | Same request | 409 with `{"currentRevision":N}`, N >= baseRevision |
| `/snapshot` | `{"accountID":"…","profileID":"…"}` | 200 with exact `scope`, UInt64 `revision`, `values` dictionary, optional `myListItemRevisions` and `myListRevisionFloor` |

`DurableMutation.swift` defines the wire fields: id, scope, deviceID, sequence, baseRevision, key,
optional value/intent/searchDeletion/myListChange. Foundation JSONEncoder encodes Data as base64,
UUID as a string, and omits nil optional fields. An absent value means deletion. SearchDeletion uses
Swift's synthesized enum Codable format (`{"all":{}}` or `{"term":{"_0":"text"}}`);
this draft is coupled to those model encodings. Agree a versioned schema before implementing another client.

The server must persist idempotency receipts and apply each immutable envelope only once. A retry
(including after a lost ACK) returns the original receipt even if subsequent mutations have committed.
Reusing an ID with changed content must not apply another effect. Revision/sequence checks and state
updates must be atomic. `revision` is an unsigned 64-bit integer; do not lose precision through a
floating-point JSON implementation.

Snapshot values and revision must be an atomic read of the same scope. Item revisions include deletion
tombstones and cannot exceed snapshot revision. The revision floor also cannot exceed snapshot revision.
If the floor is missing, this adapter uses snapshot revision as a conservative conflict boundary.
Unknown JSON fields are ignored; missing required fields, invalid base64 and wrong scopes are rejected.

## Retry and failure behavior

Only 200 is a success. 409 becomes the existing queue conflict error. 429/503 become the existing
retry status error. All other statuses (including redirects, 401 and other 2xx) are terminal for this
attempt. Snapshot reads are not automatically retried by this adapter.

Retry-After accepts nonnegative integer seconds or canonical IMF-fixdate UTC dates, with past dates
mapped to zero. Missing headers allow the existing backoff policy; malformed present headers stop the
attempt. This draft deliberately does not accept obsolete HTTP-date formats. Reference:
https://www.rfc-editor.org/rfc/rfc9110.html#name-retry-after

Wrap the adapter in `RetryingMutationTransport` for bounded mutation retries (at most four sends).
It preserves the envelope and honors the larger of jitter/backoff and Retry-After. Delays over 30 seconds
stop the current flush without shortening the server's requested delay; queued data remains pending.
The queue owns persistence and conflict reconciliation; this adapter does not delete journal entries.

The default loader uses an ephemeral session, no cookie storage/cache, no automatic redirects,
30-second request timeout, normal platform TLS validation and a 4 MiB response-body limit enforced
while reading. Cancellation is checked before and after transport execution and while streaming.
Authentication and real-server integration require a separate reviewed configuration step.

## Validation boundary

`HTTPMutationTransportTests` injects deterministic HTTPURLResponse/Data values. It tests response parsing,
request serialization, exact retry body/ID, retry timing, receipt validation, snapshot bounds, journal
retention, response size and cancellation. It does not exercise DNS, TLS, sockets, URLSession redirects,
streaming behavior, server authentication or a deployed server. Run `bash scripts/check-http-mutation-mac.sh`
on Mac and review all three output files before marking Swift validation complete.
