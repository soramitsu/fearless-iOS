# User storage compatibility models

These models repair the launch migration path for installations whose existing
database was created by the ecosystem/TON storage schema.

- `LegacyEcosystemUserDataModel_v12` is an immutable compatibility source. Its
  Core Data model checksum must remain
  `+oGDYB1AZIk54P/liFbJ3aXArqvhW7YLFAy04AChJ+s=`.
- `CompatibleUserDataModel_v13` is the active superset model. It retains the
  legacy ecosystem and TON fields and the public app's `ethereumBased` field.
  Its checksum is
  `dX3y/Aa+rMRI3ZxRibOGIkyCHwrc0zgNO9OoBnS5G/Y=`.

The compiled `.mom` files in `Compiled/` are generated with `momc`, copied into
the app bundle, and verified by migration tests. Never edit the legacy source
model in place; add a new destination model and migration edge instead.

From the iOS repository root, regenerate and audit the checked-in resources:

```sh
scripts/storage/compile-user-storage-compatibility-models.sh
scripts/storage/audit-user-storage-compatibility-models.sh
```

Run the destructive-fixture test suite for the audit itself:

```sh
scripts/storage/test-user-storage-compatibility-model-audit.sh
```

The audit compiles fresh resources, compares Core Data's semantic model
checksums, validates that both schemas retain the ecosystem and TON fields,
validates that the destination also retains `ethereumBased`, and rejects empty,
corrupt, stale, malformed, missing, or duplicated compatibility data.
