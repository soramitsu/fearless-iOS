# Historical Core Data store models (IK-1)

`manifest.json` and `Fixtures/*.mom`: every Substrate and User store model a tagged release, a
TestFlight head or a listed development build opened its stores with, compiled from the verbatim Git
blobs. Test target only; the subset the app must recognise ships from
`fearless/Common/Storage/HistoricalStoreModels/App/HistoricalStoreModels/`. Load them with
`UpgradeFixtureLoader.historicalStoreModels()`. Provenance, entry schema and the regeneration
commands are in `fearless/Common/Storage/HistoricalStoreModels/README.md`.

This folder is an Xcode folder reference: files added here are bundled into `fearlessTests` under
`HistoricalStoreModels/` without editing `project.pbxproj`.
