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
prove key installation or readback, detect removal of every iOS auxiliary
source from a payload of unknown provenance, qualify every historical cohort, or verify
an original-device-unavailable cross-platform restoration. The production
passkey recovery gate remains disabled until those checks and real device,
provider, independent security and distribution acceptance pass.

On the corrected source, the iOS 18.1 arm64 Release simulator workspace run
passed 53 wallet preflight tests and 11 Keychain projection tests, 64 total
with zero failures. Strict SwiftLint passed for the changed production Swift
files, SwiftFormat checked the verifier and projection, and the project file
parsed. These local checks are not independent security review or signed-device
acceptance.
