# Codecov Coverage Uploads

This project now produces and uploads coverage artifacts as part of the macOS Jenkins pipeline.
The `Unit Tests + Codecov Upload` stage performs the following steps:

1. Runs `scripts/test-matrix.sh` with `CODECOV_EXPORT=1` to execute the Debug and Release test
   matrix, produce `.xcresult` bundles, and persist them under `build/coverage/`.
2. Calls `scripts/ci/export-codecov.sh` to merge the `.xccovarchive` payloads and generate
   human-readable (`coverage.txt`) and machine-readable (`coverage.json`) summaries alongside the
   zipped `.xcresult` bundles.
3. Downloads the Codecov universal uploader via `scripts/ci/upload-codecov.sh` and sends the
   merged artifacts to Codecov with the `ios` flag.

## Local Usage

You can reproduce the CI behavior locally to inspect the coverage delta before pushing changes:

```bash
# Run the test matrix with coverage bundles emitted into build/coverage/
RESULTS_DIR=build/coverage CODECOV_EXPORT=1 scripts/test-matrix.sh

# Merge and inspect coverage locally (optional if CODECOV_EXPORT=1 was set above)
scripts/ci/export-codecov.sh build/coverage

# Upload to Codecov (requires CODECOV_TOKEN unless uploading from trusted CI)
CODECOV_TOKEN=<token> scripts/ci/upload-codecov.sh build/coverage
```

The generated artifacts are excluded from version control via `.gitignore`.

