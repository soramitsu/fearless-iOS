# Upgrade fixtures

On-disk state captured from historical builds: `Stores/<release>/<cohort>/` holds the store files,
`keychain.json`, `defaults.plist` and `fixture-manifest.json` for one upgrade cohort.

This folder is an Xcode folder reference: files added here are bundled into `fearlessTests` under
`UpgradeFixtures/` without editing `project.pbxproj`.
