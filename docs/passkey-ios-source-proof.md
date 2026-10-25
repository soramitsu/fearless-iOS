# iOS original Keychain source proof

`IOSPortableIOSSourceProof` is a read-only check on FPWMSM01 semantic plaintext.
The disabled iOS draft encoder runs it before returning encoded material, and
the receive inventory runs it before returning a plan. It does not upload a
backup, write a wallet, or mark recovery complete.

For iOS auxiliary sources (`sourcePlatform = 2`, raw Keychain `sourceFormat = 1`,
recipe 0), the proof checks exact byte equality against these active semantic
fields:

| Captured Keychain role | Compared semantic field |
| --- | --- |
| Root Substrate, EVM and native TON signing key | Corresponding root private key |
| Root Substrate or EVM seed and derivation path | Corresponding root seed and derivation path |
| Root entropy | Substrate/EVM entropy or native TON mnemonic, wherever that field is present |
| Scoped regular chain signing key | The chain private key for the same chain ID and account ID |
| Scoped chain entropy, seed and derivation path | Corresponding chain export field when that role is active |
| Universal-wallet source marker | Exact recognized marker, paired with a bridge-derived root seed |

It rejects mismatched active bytes. In a wallet containing at least one iOS
source, it also rejects missing root signing/TON phrase sources and missing
scoped key sources for regular chains. It rejects duplicate
Keychain destinations unless two distinct chain IDs reference the same
account-ID-scoped tag with identical bytes. The receive Keychain projection
retains both semantic chain bindings and stages one item for that tag. A
repeated binding or conflicting byte value fails closed. The proof also
rejects malformed source metadata and source bytes above the
released 4096-byte Keychain bound. The root and chain signing proofs run
separately; matching source bytes alone never establish a valid signer.

Wallet-wide items with no active matching semantic field, unused scoped roles,
and old scoped Bitcoin/Taira keys retained while the released signer derives
from the root are counted as unproven history. Android SCALE sources are handled
by their own verifier. The receive plan still reports auxiliary-source and
export-material blockers even for sources this check matches. This proof does
not make the Core Data/Keychain capture atomic, reproduce released export UX,
prove key installation, detect removal of every iOS auxiliary
source from a payload of unknown provenance, qualify every historical cohort, or verify
an original-device-unavailable cross-platform restoration. The production
passkey recovery gate remains disabled until those checks and real device,
provider, independent security and distribution acceptance pass.

`IOSReceiveInstalledKeyReadbackProof` now takes the exact semantic cohort and
receive journal, derives every expected destination item, then reads each tag
twice through the app's `KeystoreProtocol`. It rejects missing, changed or
unavailable Keychain data and never writes a key. The cohort installer must
hold its writer boundary around staging, this readback and Core Data commit;
that installer does not exist yet. Local readback is not original-key
signing/export proof or recovery acceptance.

`IOSReceiveDestinationVacancyProof` is a read-only pre-stage companion. After
the same semantic/journal projection succeeds, it rejects destination wallet
IDs already present in the caller's complete Core Data ID inventory, comparing
UUID spellings case-insensitively. It checks every planned Keychain tag twice
without fetching key bytes or writing a key, and fails on an occupied tag or
unavailable Keychain. The future installer must hold its writer boundary from
this observation through staging and Core Data commit; this proof cannot
reserve either store or make the receive transaction atomic.

On the current source, the iOS 18.1 arm64 Release simulator workspace run
passed 53 wallet preflight, 11 Keychain projection, three installed-readback
and three pre-stage vacancy tests, **70/70** total with zero failures or skips.
Strict SwiftLint and SwiftFormat passed on the proof and test source; the diff
check passed. These local checks are not independent security
review or signed-device acceptance.

The FPWMSM01 codec now accepts optional Android display metadata IDs 10
(selected chain) and 11 (chain-selector filter) as exact strict UTF-8 strings.
The receive projection preserves absent versus explicitly empty values and
rejects invalid UTF-8, oversize strings, unknown IDs and noncanonical order.
The receive plan retains both values and its metadata-install blocker; no iOS
wallet metadata is changed or installed from them yet. The exact 70-byte
Android display-metadata vector is asserted by the iOS codec. The final-source
iOS 18.1 arm64 Release simulator run passed 21/21 semantic-codec, receive
projection and prospective sidecar tests with no skips or failures. This
establishes byte and read-only destination compatibility, not installation or
replacement-device recovery.

The Android `wallet_selected_chain_id<id>` preference feeds the balance and
asset-management selected chain; `chain_select_filter_applied_<id>` stores a
chain-selector enum name. These are independent of iOS's Core Data
`networkManagmentFilter` (portable metadata ID 4), which drives the wallet's
network and NFT view. In particular, iOS interprets an empty filter identifier
as `.chain("")`, not as the absence of a selection. Reusing ID 4 would both
change display behavior and erase the distinction between absent and explicitly
empty Android values. The receive plan now describes a prospective sidecar for
IDs 10/11/12, bound to the source portable wallet ID. Given a journal for the
exact semantic cohort, a read-only projection resolves each candidate to its
fresh iOS destination wallet ID. It keeps absent and explicitly empty values
distinct and does not map either value to iOS metadata ID 4. Metadata ID 12
creates a candidate even when IDs 10/11 are absent; its asset-row wire bytes
are retained exactly. Binding rejects a substitute value with different raw
UTF-8 bytes even when Swift considers the text canonically equivalent. No
sidecar is written, and the plan retains its metadata and transactional-installer blockers.
A wallet-bound durable destination, atomic installation and readback are still
required before recovery can be enabled.
