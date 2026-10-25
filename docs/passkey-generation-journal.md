# Local immutable generation journal

`PasskeyBackupGenerationJournal` is a disabled iOS recovery building block. It
stores only the canonical FPBKGEN1 encrypted generation, its SHA-256, the
preallocated Google Drive file ID, exact operation ID and authenticated
generation context. The local record is checksummed and bounded to the
512 KiB generation plus 8 KiB of journal metadata. It never stores a plaintext
wallet, backup key or WebAuthn PRF output.

The caller must supply the owner subject, backup namespace and verified stable
Google account binding from authenticated state. File contents cannot establish
that authority. Each operation ID names one immutable private record. The
journal rejects different bytes for an existing operation, reuse of a Drive ID
within one Google account, and reuse of a generation ID within one owner
namespace. It retains unresolved records; there is no overwrite, cleanup,
head mutation or network request API.

The journal creates its directory under Application Support with a no-backup
attribute and complete file protection, checks private file and directory
ownership/modes, refuses symlinks, serializes local and cross-process access,
and synchronizes each new file, the containing directory and its parent
directory entry before returning. A complete-looking record left by an
interrupted write is explicitly re-synced before it can authorize an attempt;
the same check runs even for direct attempt admission. An interrupted or
malformed record remains in place and fails closed. The
separate attempt marker binds the SHA-256 of the exact prepared record. The
first durable marker creation admits one application-level Drive create
attempt; a restarted caller seeing that marker must read and reconcile the
same preallocated Drive ID instead of silently posting again. A marker does
not prove that a request reached Drive, and URLSession cannot prove exactly
one physical transmission.

`GoogleDrivePasskeyGenerationStorage.createCandidate` requires this journal,
an operation ID and an independently authenticated owner/account scope. It
stages the exact candidate and durably marks the attempt before invoking the
transport; repeat calls return `reconcileRequired` without another POST.

The [round-trip coordinator](passkey-generation-coordinator.md) now downloads
the same ID and requires a mandatory injected local wallet verifier before
returning local evidence. Production decryption and wallet verification still
need wiring. The owner grant and authoritative head CAS must retain the
previous decryptable generation through an interrupted replacement and define
monitored recovery for unresolved markers. The release flag remains off; real
iOS-to-Android and Android-to-iOS replacement-device tests are still required.
