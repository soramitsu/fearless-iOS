# Immutable Google Drive generation storage candidate

`GoogleDrivePasskeyGenerationStorage` is a disabled recovery building block. It stores canonical FPBKGEN1 ciphertext with the same byte layout, metadata and file naming as Android. It does not authorize a wallet owner, invoke a passkey, unwrap a backup key, decrypt a wallet, change the authoritative head, overwrite or delete a Drive file. Production recovery remains disabled.

The older single-file Drive adapter remains able to read historical encrypted backups. It now refuses to PATCH an existing backup; that path could replace the last decryptable copy before the new generation is locally verified. Existing records must be migrated through the immutable generation flow, and a legacy overwrite is never treated as a completed backup.

The caller must obtain an authenticated owner/namespace and the current head before preparing a generation. A Google account identifies only the ciphertext storage account. Each request obtains fresh scoped authorization and requires the pinned Google `sub`; an email rename preserves the original FPBKAEAD accountName and authenticated bytes. Both apps must use the same approved Google project and Drive appData consent scope.

1. Allocate a file ID with `GET /drive/v3/files/generateIds?count=1&space=appDataFolder&type=files`. Require exactly one ID for the appData space.
2. Prepare the bounded canonical bundle and persist the ID, exact bytes, digest, expected owner head and operation ID in a durable journal **before** calling `createCandidate`.
3. Issue one multipart `POST /upload/drive/v3/files?uploadType=multipart&fields=id,name,mimeType,spaces,appProperties,size` with that ID, `parents: ["appDataFolder"]`, and the exact prepared ciphertext. No replacement ID, PATCH, DELETE, automatic retry or head mutation is provided.
4. Treat timeout, network failure, cancellation after admission, malformed acknowledgement and HTTP 409 as requiring reconciliation of the same journaled ID. A 200/201 acknowledgement only confirms matching metadata; it is not decryption proof. The [round-trip coordinator](passkey-generation-coordinator.md) handles repeated invocations and restart using the journal.
5. Read exact metadata, then `GET /drive/v3/files/{id}?alt=media`. Require exact ID/name/MIME/space, closed appProperties, canonical size, byte count, SHA-256 and all expected FPBKGEN1 context fields. A 404 is only an observation, not permission to abandon or recreate the generation.

The guarded replacement-device readback can now use a read-only owner-head
HTTP adapter. It sends a canonical `{"schemaVersion":1}` request with a
server-issued owner session to `/api/passkey-backup/v1/owner/backup/head`,
requires an exact bounded response with no duplicate decoded JSON keys, and
checks owner, backup namespace, Google storage binding and parent history
before selecting a Drive file. The adapter derives the expected binding from
the verified selected Google subject through the same token-provider contract
used for Drive; it does not accept a caller-supplied digest or send a Drive
token to the owner service. It checks owner-session expiry before and after
the request and rechecks the selected Google subject after the response.
After local decryption and original-key proof,
it fetches the authenticated head again and rejects a changed head or revoked
session before returning local evidence. This path still does not install a
wallet or mark a backup complete. A separate disabled iOS 18+ authentication
adapter now requests a discoverable, user-verified native passkey assertion with
no credential hint or PRF extension, sends only the public WebAuthn assertion to
the owner authority, and accepts a short-lived session from an exact, bounded
response. It does not use a Google account as owner proof. This candidate is
not connected to production recovery UI or a deployed owner service. Native
completion and cancellation callbacks are bound to their exact ceremony
attempt, so a delayed cancellation cannot terminate a successor prompt.

An unwired owner-generation HTTP candidate now covers metadata-only grant,
commit and operation-status calls. It prepares the exact ten-field request
from an immutable Drive candidate and authenticated current/previous head,
then checks the selected Google subject through the same token provider as
Drive before and after each owner request. A short-lived grant is bound to
that exact request and owner session; the commit reuses the identical body.
Responses are bounded and reject duplicate decoded JSON members, coercions,
unknown fields and substituted generation descriptors. The owner service
receives no Drive token, PRF output or wallet plaintext. A successful metadata
commit does not prove that the ciphertext was uploaded, downloaded and
decrypted, or that original keys sign and export. Production recovery remains
disabled and no caller marks backup complete through this adapter.

The four appProperties are `format=FPBKGEN1`, `namespaceSha256=SHA256(UTF8(backupNamespace))`, `generationId`, and `bundleSha256`. The name is `fearless-passkey-generation-{generationId}.bin`. Metadata is bounded to 8 KiB and rejects duplicate decoded JSON keys, trailing JSON, unknown fields, coercions and ambiguous arrays. The store defaults to the dedicated `URLSessionPasskeyGenerationTransport`, while retaining explicit transport injection for tests. This transport bounds decoded responses to 512 KiB, disables redirects, cookies, credential storage and caching, sends POST through an input stream and refuses replacement streams and HTTP authentication retries. URLSession exposes no blanket switch proving exactly one physical transmission; these controls prevent application retries and requested stream regeneration. It does not promise that losing a network response means no bytes reached Drive. The preallocated file ID and mandatory reconciliation handle unknown outcomes. The legacy challenge/envelope transport remains capped at 256 KiB.

The Android/Node fixed vector is 785 bytes with SHA-256 `1c92b544dc25c687c202317d0e5747b5690a1056cf72e61d1dfab84c07c057a4`. Tests also cover a maximum-size 256 KiB legacy envelope inside the larger generation without changing its bytes or limit.

Remaining integration gates: production owner authentication and grant qualification, full-live monotonic head/CAS acceptance; production local unwrap/decrypt and original-key wallet verification wiring; synchronized credential enrollment/revocation/key-epoch rotation; real Google consent/provider and replacement-device tests in both directions; retention of the last decryptable and unresolved generations; independent source/device/security acceptance. No UI or release flag is enabled by this patch.

Primary API references: [Drive generateIds](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/generateIds), [pre-generated IDs](https://developers.google.com/workspace/drive/api/guides/create-file#generate-ids), [Drive appData](https://developers.google.com/workspace/drive/api/guides/appdata), [file metadata](https://developers.google.com/workspace/drive/api/reference/rest/v3/files), and [Foundation replacement body streams](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession(_:task:neednewbodystream:)).
