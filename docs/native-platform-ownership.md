# iOS source ownership

The iOS application owns its native Swift and C modules in `Native/`, its transport in `Native/Sources/Starscream`, and its remote data under `remote-config/`. Xcode builds the local `FearlessNative` package. Native modules are changed and tested in the same pull request as their app consumers; no sibling checkout or separately published Fearless shared package is required.

Public CocoaPods and external Swift packages remain pinned by the committed lockfiles. Service configuration comes from the build environment through the existing CI generators. There is no private keys pod.

`config/native-sources.json` records the reviewed import commits and the exact prebuilt native slices. First-party source is editable app code. The existing SSF module names are retained to preserve Swift API, stored-model, and serialization compatibility; they do not indicate a separate repository dependency. Swift/C/Rust tests, fixtures, and native build/provenance scripts live with their implementation.

`config/remote-config-imports.json` records initial data imports, nested URL rewrites, and explicit artwork corrections. It pins every file under `remote-config/` by SHA-256 (`ownedSha256`), and `scripts/verify-remote-config.py` fails on a missing file or a stale pin, so an edit re-pins the file and appends a `corrections` entry in the same commit. Production data includes route retirement and the lcDOT GeneralKey length fix; development has its independent configuration. Future data changes are reviewed in this app repository. Legacy public data URLs remain hosted for older installed apps until those consumers can be retired.

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

## Xcode build-phase tools

The resource generation phase uses R.swift 6.1.0. The lint phase uses SwiftFormat 0.47.13. `R.swift.Library` 5.3.0 supplies the runtime Swift source through CocoaPods. The host tools build separately from the app using the selected Xcode toolchain.

`BuildTools/sources.json` records the upstream repositories, release tags, Git commits and Git object IDs for both executables and R.swift's dependencies, Commander and XcodeEdit. The selected upstream sources and licenses are vendored in `BuildTools/Vendor/`. R.swift's upstream lockfile supplies the Commander and XcodeEdit revisions. Its test-only Spectre dependency is outside the executable's build graph.

For each source snapshot, `BuildTools/Provenance/` retains the upstream Git commit and the tree entries for omitted paths. The verifier hashes the vendored files and modes, reconstructs the upstream root tree, and checks the tree and commit IDs offline. To independently check an import, export the listed paths with `git archive <revision> -- <paths...>` in the upstream repository and compare them with the corresponding vendor directory.

```sh
scripts/deps/build-tools-from-source.sh
python3 -I scripts/deps/verify-build-tools.py
```

The bootstrap verifies the vendored sources against the pins and produces release executables under the ignored `build/source-tools/bin/` directory. A clean tool build needs no network access. Local rebuilds reuse products whose hashes match the build receipt and current inputs. CI and the release archive scripts pass `--force` to compile fresh executables. Xcode verifies the pins and local executables before running the tools. If verification fails, restore any changed vendored files and rerun the bootstrap.
