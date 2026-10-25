# Legacy asset visibility fixtures (IOSUX-6)

Fixtures produced by `generate.py`, which re-implements the visibility writers of App Store 4.0.4
(tag `4.0.4`, `195b02307`), of 3.6–3.7.4 and of the TestFlight 2026.9.x builds (`9415f7f7b`) over the
reviewed registry snapshot in `../Registry/`, so the expected upgrade results do not depend on the code
under test. `python3 generate.py --check` fails when a committed fixture differs from what the script
writes.

| Fixture | Wallet |
|---|---|
| `404-regular-scanned` | regular 4.0.4 wallet after a Manage pull-to-refresh |
| `404-auto-hidden-then-funded` | scanned by 4.0.4 while empty, funded later |
| `374-migrator` | rows rewritten by the 3.6–3.7.4 `AssetManagementMigrator` |
| `v9-asset-ids-enabled` | rows the Core Data V9 policy made from `assetIdsEnabled` |
| `404-ton-optout` | 4.0.4 TON wallet with its own hides |
| `testflight-v1-applied` | 4.0.4 rows, then a TestFlight build: first AssetKey migration, scan-written Shown, user choices |
| `testflight-new-wallet` | wallet created on a TestFlight build: scan-written Shown only, plus user choices |

`storedPreferences` in the TestFlight fixtures holds the `UserDefaults` key suffixes
(`ecosystem:chainId:assetId`) exactly as those builds derived them; the tests write them raw.

`LegacyVisibilityMigrationV2Tests` also writes the `404-regular-scanned` and `v9-asset-ids-enabled` rows
into stores built with the Core Data models that shipped and upgrades them with the release's own
`UserStorageMigrator`, so the rows reach the visibility migration the way they do on a device.

This folder is an Xcode folder reference: files added here are bundled into `fearlessTests` under
`LegacyVisibility/` without editing `project.pbxproj`.
