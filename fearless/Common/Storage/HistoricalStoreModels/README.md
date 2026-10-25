# Historical Core Data store models

Every Substrate and User store model that a Fearless iOS build ever opened its
stores with, taken verbatim from Git history. Shipped models were edited in
place several times (for example `SubstrateDataModel_v5` has 13 historical
contents, and `ce458b935` rewrote v2–v8), so the lineage models in
`SubstrateDataModel.xcdatamodeld` no longer match many stores that real builds
wrote. This folder is the auditable source of truth for those schemas.

| Path | Contents |
|---|---|
| `Source/<Store>Historical_<digest>.xcdatamodel/contents` | The exact Git blob, plus the repository's conventional final LF when the blob has none. Never edited. Not part of the Xcode project. |
| `App/HistoricalStoreModels/<Store>Historical_<digest>.mom` | Only the models the release does not recognise otherwise (manifest entries with a `landing`). An Xcode folder reference ships this folder in the app as `HistoricalStoreModels/`. |
| `fearlessTests/Resources/HistoricalStoreModels/manifest.json` | One entry per schema digest: provenance, role and landing policy. Test target only. |
| `fearlessTests/Resources/HistoricalStoreModels/Fixtures/*.mom` | Every model in the manifest, compiled. Test target only, so upgrade tests start from the exact models releases shipped instead of from today's lineage. |

## Provenance

`scripts/storage/extract-historical-store-models.py` reads, with read-only Git
commands only, every tag of `fearless-iOS` and `fearless-iOS-priv`, the
TestFlight 4.2.0 heads and the untagged development commits it lists. For each
build it resolves the model the build opened each store with:

- Substrate: the `.xccurrentversion` of `SubstrateDataModel.xcdatamodeld` (the
  1.x builds had a single model);
- User: `UserStorageParams.modelVersion` through that build's own
  `UserStorageVersion` raw values, from the app's compatibility sources, the
  pinned `shared-features-spm` `SSFAccountManagmentStorage` bundle, or the
  app's `UserDataModel.xcdatamodeld`.

The private repository and `shared-features-spm` contribute only Core Data
schema XML; there are no secrets, wallet data or user data here.

The digest is the first 16 hex characters of SHA-256 over the entity version
hashes, sorted by entity name and joined as `name=base64(hash)` with `;`. Equal
digests open the same stores, so blobs that differ only in XML layout share one
entry and list the other blobs in `equivalentGitBlobs`.

## Manifest entry

```json
{"store": "substrate", "digest": "d484c09eddea88ca", "resource": "SubstrateHistorical_d484c09eddea88ca",
 "gitBlob": "3bb8ef9fc55f5b64ae8debf71072c77a3b421ff0", "equivalentGitBlobs": [],
 "xmlSha256": "…", "versionChecksum": "…", "sourceRepo": "pub", "sourcePath": "…", "modelNames": ["SubstrateDataModel_v5"],
 "tier": "appStore", "releases": ["pub:3.2.2", "…", "priv:3.5.3"], "interimTags": ["pub:3.2.2.1", "…"],
 "heads": [], "developmentCommits": [],
 "matchesBundled": null, "landing": "SubstrateDataModel_v5",
 "allowedDrops": {"entities": ["CDSingleValue"], "attributes": []}, "requiredConstants": {}, "excluded": null}
```

- `tier`: `appStore` when an `x.y.z` release tag shipped the model, `testFlight`
  when only build tags (`x.y.z.n`, `-n`, `RC`) or TestFlight heads did,
  `development` for untagged development commits.
- Exactly one role is set:
  - `matchesBundled`: the release already bundles a model with this digest (a
    lineage or compatibility resource). Test fixture only.
  - `landing`: the lineage model the store migrates to first, chosen from the
    same schema family so the real downstream hops only see data that has not
    been through them. These models ship in the app. `allowedDrops` is the
    reviewed set of cache-only entities and `Entity.property` names Core Data's
    inferred mapping drops; `requiredConstants` supplies values for mandatory
    attributes the source lacks, which the inferred mapping would leave empty
    and fail on (1.0–1.6 local transfers get the call path 1.7 wrote,
    `transfer`/`Balances`; the first TON Connect development builds stored no
    app name, so those connected apps get an empty name and keep everything else).
  - `excluded`: inventoried but not migrated automatically (the two August
    2024 development models whose `CDAsset.priceData` transformable is not in
    the migrator's allowlist). Like any Substrate store the release cannot
    use, such a store is moved whole into `SubstrateStoreRetained/<uuid>/`
    beside it and the app opens with fresh network data; nothing is deleted.

## Rules

- Never edit a source model in place, and never reuse a resource name for other
  contents. A new shipped schema gets a new entry.
- Landing policy lives in `POLICY` in the extractor and is reviewed there.
- The migrator recognises an app-bundled entry by its digest and must fail
  closed if the inferred mapping would drop anything outside `allowedDrops`.
  Failing closed never stops the app from opening: the unchanged store is set
  aside (`RetainedStoreSetAside`), so a later build can still migrate it.
- User landings only add attributes (`allowedDrops` is empty), and every
  landing hop runs the same per-hop integrity and wallet-count checks as the
  lineage hops. The one same-named attribute whose definition changes,
  `CDMetaAccount.hasBackup` from TestFlight 2.4.1.1–2.4.1.2 (optional, read
  as `false` when empty, then required with default `NO`), is checked by its
  own semantic snapshot instead. A User store holds wallet identity, so one
  that fails closed is never moved: it stays in place, untouched, for guided
  startup recovery.

## Commands

From the iOS repository root:

```sh
# Regenerate Source/ and manifest.json from the three repositories (needs
# ../fearless-iOS-priv next to the main checkout and the shared-features
# repository under SourcePackages/repositories; both paths can be overridden).
scripts/storage/extract-historical-store-models.py

# Compile App/ and Fixtures/ from Source/ and the manifest.
scripts/storage/compile-historical-store-models.sh

# Offline audit (CI): provenance, compiled identities, digest uniqueness, drop sets.
scripts/storage/audit-historical-store-models.sh

# Release audit: also re-resolve every tag, head and development commit.
scripts/storage/audit-historical-store-models.sh --repos

# The audit's own destructive-fixture suite, and the extractor's resolution rules.
scripts/storage/test-historical-store-model-audit.sh
python3 scripts/storage/test-extract-historical-store-models.py
```
