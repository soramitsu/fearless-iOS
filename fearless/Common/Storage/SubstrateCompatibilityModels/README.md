# Substrate storage compatibility models

These immutable sources identify public App Store Substrate stores whose
compiled model hashes are not present in the modernized model lineage.

- `LegacyPublicSubstrateDataModel_v8` is the model shipped by the public
  App Store 4.0.4 line. Its source is Git blob
  `98daa733cb798fc2245c1d60ed66c366d7a30d4a` and its original XML SHA-256 is
  `d5634c446b0881d261f58d5317eff72cc54d06d8f2679a1301056e689740ea29`.
- `LegacyPublicSubstrateDataModel_v9` is the model shipped by the public
  App Store 4.0.5 and 4.1.0 lines. Its source is Git blob
  `26899179e07abd06086a012c3325d1ac62ac5509` and its original XML SHA-256 is
  `aa0fede5a4ee217e0c6be45f7379ca9c3583edde4e0ee379fa0756641728b769`.

The checked-in XML adds only the repository's conventional final LF. The
audit removes exactly that LF before checking both immutable Git-blob and
SHA-256 provenance. It also recompiles the sources with the production
`momc` module/deployment settings and pins their Core Data version checksums.

The compiled models are source-only compatibility detectors and migration
origins. The active `SubstrateDataModel_v10` remains in the main `.momd` and
is the lossless union of the modernized v8 model and the two public models:
it retains `ethereumType`, `coinbaseUrl`, the TON chain fields, and both TON
entities. Explicit v8-modernized, v8-public, and v9-public edges migrate to
v10; no public model is ever opened as the destination or mapped down to v8.

Regenerate and audit with:

```sh
scripts/storage/compile-substrate-storage-compatibility-models.sh
scripts/storage/audit-substrate-storage-compatibility-models.sh
```

These resources were derived from public repository history. They contain no
phone, wallet, Keychain, address, or database contents.
