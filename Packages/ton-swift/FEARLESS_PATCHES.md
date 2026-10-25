# Pinned TON SDK compatibility patches

Vendored from https://github.com/tonkeeper/ton-swift at 1.0.4, revision `03dbe1f4cef7471b012993ec54e0783882acb3ab`. Original Apache 2.0 license retained.

The app uses the same pinned signing, key derivation and V4R2 implementation. Local changes are limited to:

- TON exotic library-reference cells (type 2): exact 264-bit/no-reference validation, level-zero hash calculation. These occur in contract StateInit code cells; their library hash must remain a reference, never be treated as ordinary inline code.
- Preserve multilevel exotic-cell hashes: use the level mask in descriptors, the original bit-length descriptor for higher hashes, and the specified hash-array then depth-array order for pruned branches. Ordinary level-zero wallet cells remain byte-identical.
- Reject invalid BOC reference and root indexes with a thrown error, avoiding out-of-bounds traps on untrusted contract payloads. The app applies additional bounded wire preflight.

Independent @ton/core cell/StateInit/transfer vectors and existing native signing vectors cover compatibility. Replace this local package only when an upstream pinned version passes the same checks; revert the aggregator package path and remove this directory to return to the original 1.0.4 dependency.
