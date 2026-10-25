# iOS source ownership

The iOS application owns its native Swift and C modules in `Native/`, its transport in `Native/Sources/Starscream`, and its remote data under `remote-config/`. Xcode builds the local `FearlessNative` package. Native modules are changed and tested in the same pull request as their app consumers; no sibling checkout or separately published Fearless shared package is required.

Public CocoaPods and external Swift packages remain pinned by the committed lockfiles. Service configuration comes from the build environment through the existing CI generators. There is no private keys pod.

`config/native-sources.json` records the reviewed import commits and the exact prebuilt native slices. First-party source is editable app code. The existing SSF module names are retained to preserve Swift API, stored-model, and serialization compatibility; they do not indicate a separate repository dependency. Swift/C/Rust tests, fixtures, and native build/provenance scripts live with their implementation.

`config/remote-config-imports.json` records initial data imports, nested URL rewrites, and explicit artwork corrections. Production data includes route retirement and the lcDOT GeneralKey length fix; development has its independent configuration. Future data changes are reviewed in this app repository. Legacy public data URLs remain hosted for older installed apps until those consumers can be retired.

Validation:

```sh
python3 scripts/deps/test-native-source.py
python3 scripts/deps/verify-native-source.py .
python3 scripts/verify-remote-config.py
python3 Native/scripts/test-xcm-read-only-boundary.py --self-test
python3 Native/scripts/test-authorized-rpc.py
bash scripts/test-matrix.sh
(cd Native && xcodebuild test -scheme FearlessNative-Package -destination 'platform=iOS Simulator,name=iPhone 16')
```

Import notices and source licenses are retained under `Native/`. The reviewed first-party Apache-2.0 transition is recorded separately from the runtime import; alternative MIT grants and third-party notices remain intact. `Native/Binaries` contains the existing sr25519 and SORA wallet slices; source and rebuild instructions are retained alongside them.
