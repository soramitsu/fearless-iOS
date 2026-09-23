# Native Google Drive passkey backup adapter

Passkey recovery remains disabled. This adapter stores an already encrypted backup; it does not implement PRF recovery, issue owner grants, or establish wallet ownership from a Google login.

`GoogleDrivePasskeyBackupTokenProvider.requestConsent` is an explicit user action. It uses the already pinned GoogleSignIn 7.1.0 SDK, requests `https://www.googleapis.com/auth/drive.appdata`, and returns the selected Google subject/email for the account confirmation UI. Subsequent storage operations refresh tokens without presenting UI and reject a missing account, changed subject, wrong OAuth client, missing scope, expired token or cancellation. The subject identifies the Drive account only; it must never replace the stable Fearless owner subject.

The native adapter validates the built application's `GIDClientID` and exactly one matching reversed-client URL scheme before invoking Google. The existing release service configuration process supplies those values; source contains no replacement client ID. Android and iOS must use native OAuth clients belonging to the same reviewed Google Cloud application/project, and the user must select the same Google account. Real bidirectional device tests must demonstrate visibility of both the hidden files and their private app properties. A passing unit test does not establish that configuration.

The registered Google callback handler admits only the configured URL scheme, then delegates OAuth state validation to Google's SDK. Existing URL handlers and legacy password backups remain available. No automatic sign-out, scope revocation, background account selection or fallback to a different Google account is performed.

## Portable storage format

The adapter reads and writes the existing Android format:

- Filename: `fearless-passkey-backup-<storageKey>.bin` in `appDataFolder`.
- Media type: `application/octet-stream`; media bytes are the unchanged canonical `FPBKAEAD` envelope.
- Five string `appProperties`: `storageKey`, `walletId`, `accountName`, `createdAtMillis`, `schemaVersion`.
- Original AAD metadata is preserved when reading, including an earlier account email after a Google email change.

The current Android provider binds storage access to `Account(email)` and requires matching metadata email. It therefore rejects the renamed-email case that this iOS subject binding can read. That remains a cross-platform recovery gap until Android has stable Google-subject binding and the shared owner/lifecycle protocol is complete; this iOS test is not bidirectional acceptance evidence.

Create uses multipart metadata and encrypted bytes with the `appDataFolder` parent. Update omits the parents field. Each request obtains a refreshed token for the selected subject. Search explicitly requests pagination metadata and denies a partial search or duplicate filename rather than choosing one file or assuming absence. Successful uploads must acknowledge the expected filename and exact metadata; updates must acknowledge the same file ID.

Google limits each private property's key plus value to 124 UTF-8 bytes. This implementation rejects larger metadata before requesting a token; it never truncates authenticated metadata. The shared wallet/account validators allow some larger values. A reviewed cross-platform format revision is required to support those values, portable credential wrappers and backup generations together.

The HTTP transport uses the existing ephemeral, cookie-free, cache-free session, rejects redirects, limits responses to 256 KiB, propagates cancellation and has bounded request/resource timeouts. Requests target fixed Google Drive HTTPS endpoints. There is no application-level retry after an upload, timeout, 401 or cancellation. Failure after a request has been sent does not prove that Google did not store it.

## Remaining release gates

`PasskeyBackupComposition.makeGoogleDriveClient` keeps the compiled release gate and unavailable owner/key defaults. CloudKit remains an explicitly selected optional additional copy; it is never a silent fallback from failed Google Drive access. This patch adds no visible enabled recovery flow.

Before enabling recovery, complete native PRF and key wrapping, exact-request owner grants, successful local-decryption proof before enrollment, safe final-credential removal/key rotation, and generation-aware cross-device update/rollback protection. Drive list-then-create/update is not an atomic cross-device transaction. Concurrent creates can result in duplicates, which later reads intentionally reject. Concurrent updates and challenge/store coordination still require the reviewed lifecycle protocol.

Qualification must include live account selection/denied consent/cancellation, account changes during refresh, same-project Android↔iOS replacement-device restore, preserved AAD and wrapper migration, no plaintext/key/PRF/token leakage, and store-signed upgrade testing. Local tests use synthetic authorization and transport fixtures; they do not sign into Google, store live ciphertext, or validate lost-device recovery.

Official references: [native Google API access](https://developers.google.com/identity/sign-in/ios/api-access), [GIDGoogleUser refresh APIs](https://developers.google.com/identity/sign-in/ios/reference/Classes/GIDGoogleUser), [Drive app data](https://developers.google.com/workspace/drive/api/guides/appdata), [property limits](https://developers.google.com/workspace/drive/api/guides/properties), [file updates](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/update).
