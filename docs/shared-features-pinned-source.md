# Pinned shared-features source

The wallet's dependency source is bound by `config/shared-features-source.json`.
Its current candidate is PR #84 (read-only XCM), stacked on PR #83 (guarded RPC)
and PR #82 (compatibility fixes for the exact previously pinned wallet SDK line). The guarded transport is separately
bound by `config/starscream-source.json` to Starscream PR #5. PR #81 targets a different API/storage line and cannot replace this pin
without separate wallet migration qualification.

`scripts/deps/verify-shared-features-source.py` checks both resolver files, the
Xcode project and FearlessUtilsCompat against that source contract. Both resolver
files must also select the exact Starscream revision; a missing transport contract
or ambiguous JSON field fails verification. After package resolution it verifies
both actual checkouts and the shared SDK's transport dependency declaration. For
each checkout it checks HEAD, Git tree, staged changes, each file's exact Git blob
identity and executable mode, symbolic links, missing files, and additional files
including ignored files. It uses only the explicit `SOURCE_PACKAGES_DIR`, or the
workspace's `SourcePackages` default, and never falls back to another checkout.
An existing stale/modified checkout must be preserved and replaced by a freshly
resolved candidate; no build helper will repair it in place.

CI, local setup, the test matrix, and the Xcode build phase all run this read-only
verification. The four historical patch helper entry points are compatibility
wrappers for the verifier. Pin enforcement verifies instead of rewriting pins.
There is no exception that permits a dirty dependency in a production build.

For an isolated cache, pass both
`-clonedSourcePackagesDirPath /absolute/path/to/SourcePackages` and
`SOURCE_PACKAGES_DIR=/absolute/path/to/SourcePackages` to `xcodebuild` so its build
phase verifies the checkout actually compiled. Readiness commands use that same
`SOURCE_PACKAGES_DIR` environment variable.

Run:

```sh
python3 scripts/deps/test-shared-features-source.py
bash scripts/deps/test-shared-features-delta-report.sh
SOURCE_PACKAGES_DIR=/absolute/path/to/SourcePackages \
  bash scripts/deps/audit-shared-features-delta-report.sh --require-ready
```

`removalReadiness=ready` means resolved dependency patching has been removed and
the actual candidate source matches its pin. `releaseQualified` stays false:
independent review, protected-branch CI, final wallet source, native symbol
coverage and store-delivered upgrade acceptance are separate required gates.
