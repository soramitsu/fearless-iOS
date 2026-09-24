# iOS encrypted-generation round trip

`PasskeyBackupGenerationCoordinator` connects the immutable FPBKGEN1 Drive
store and the local attempt journal. Its caller supplies the current owner,
namespace and verified Google account binding, plus an expected wallet ID,
storage key and digest of the original wallet's public identities. Those
values must come from independently authenticated owner and wallet state, not
from Drive metadata, a downloaded bundle or a local journal file.

For a new operation, the coordinator durably records the exact canonical
ciphertext, operation ID and preallocated Drive file ID before it admits the
single create attempt. A timeout, ambiguous acknowledgement or 404 leaves
the journal and attempt marker intact. A restarted caller resumes by operation
ID, reads the same Drive ID and never sends a second POST. No branch of this
API allocates a replacement ID, overwrites, deletes or changes an owner head.

A matching Drive acknowledgement is insufficient. The coordinator fetches
metadata and media, requires the store's strict FPBKGEN1 context, size and
SHA-256 checks, compares the re-encoded canonical bytes to the exact journaled
bytes, and then invokes a mandatory `PasskeyLocalWalletVerifier`. The verifier
contract requires local credential unwrap, AES-GCM decryption, public wallet
identity comparison, an original-key signing check and an original-key export
check. The coordinator rejects missing, false or mismatched evidence, then
re-reads the exact attempted journal entry and selected Google account after
the asynchronous verifier. Only after these checks does it return
`PasskeyBackupLocallyVerifiedGeneration`,
which is evidence of this round trip alone.

`PasskeyBackupCryptoVerifier` now accepts only the typed local
PRF result released after challenge verification. It requires the exact
credential wrapper and salt, unwraps the backup key, decrypts FPBKAEAD, and
checks the wallet callback's original identity, signing and export evidence.
The local unwrap now goes through a one-use `PasskeyBackupVerifiedPRFKeyProvider`.
It binds the native credential ID and salt to the independently supplied
owner/wallet/epoch/metadata wrapper context, burns the PRF capability before
returning a key, and rejects changed metadata or a second call. A PRF result
cannot be reused by a second provider. The old string-only backup client still
defaults to `UnavailablePasskeyBackupKeyProvider`: it cannot obtain a verified
PRF result before its registration key request and must not be wired to this
provider without replacing that lifecycle.

The read-only `PasskeyBackupHeadReadbackVerifier` is the replacement-device
counterpart. Given a head and expected wallet identity obtained independently
from an authenticated owner session, it reads only that exact Drive file and
digest, requires a server-verified local PRF result to unwrap and decrypt it,
then invokes the original-wallet identity/signing/export verifier. It checks
the selected Google account again after that asynchronous local verification.
Its redacted result is local evidence for one observed head revision, not a
wallet-installation command, fresh owner authorization or proof that the head
has remained current. The read-only owner-head HTTP source now derives the
expected account binding from the verified selected Google subject rather
than a caller-supplied digest, and rejects an expired owner session or an
account switch during its request. The readback verifier checks session expiry
again after its final asynchronous Drive-account check. Before installation,
the caller must re-authenticate
the owner, compare the current head and key epoch, and complete the separate
wallet migration checks. There is no production owner flow or installation
caller for this primitive yet.

The disabled `PasskeyBackupVerifiedGenerationPromotion` candidate now composes
the journal, immutable Drive storage, local cryptographic verifier, authenticated
owner head, and metadata grant/commit client. It first queries operation status
using a reference reconstructed from the exact durable candidate. That lookup
still works after a successful commit advances the parent head. If the operation
is absent, promotion uploads or reconciles the one candidate, downloads its
exact bytes, consumes a verified PRF once to decrypt and check the original
wallet, rechecks the owner head and Google account, then requests a single-use
grant and conditional owner commit. A lost commit response triggers read-only
operation reconciliation; it never triggers a second upload or blind commit.
The prior decryptable owner head remains until the server has committed the
candidate. On successful commit, the client reads the new authenticated head
and exact Drive bytes again, comparing them to the ciphertext already decrypted
before commit. A restarted committed operation instead requires a fresh PRF
ceremony and full head decryption/signing/export verification. The result is
still local evidence, not a persisted backup-complete marker or a recovery
installation authorization.

Its mutable local PRF, key and plaintext `Data` buffers are reset after use;
Swift/CryptoKit and the wallet callback may retain other copies, which need
security review. Its tests use synthetic wallet material; the production wallet
migration/signing/export callback is not implemented or wired into the app.
Owner/grant deployment and qualification, transactional head update, retention,
credential rotation, device/provider interoperability and distribution tests
remain release gates. The passkey recovery flag stays disabled.
