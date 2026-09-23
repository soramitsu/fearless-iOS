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
check. The coordinator rejects missing, false or mismatched evidence. Only
after these checks does it return `PasskeyBackupLocallyVerifiedGeneration`,
which is evidence of this round trip alone.

There is no production verifier implementation in this increment. Wiring the
native PRF ceremony, credential-key unwrap and existing AES-GCM envelope to
the actual wallet migration/signing/export paths needs separate review. The
owner/grant authority, transactional head update, retention policy, credential
rotation, device/provider interoperability and distribution tests remain
release gates. The passkey recovery flag stays disabled. A test verifier
exists only in the simulator fixture and cannot be selected by production
code.
