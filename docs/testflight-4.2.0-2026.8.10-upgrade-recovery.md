# TestFlight 4.2.0 Upgrade Recovery Gate

Build `4.2.0 (2026.8.10)` is the upgrade-recovery hotfix based on source commit
`2e45e55dc03ad904598e730cfb5994fb5c1072dc`. It must remain blocked from the
public beta group until the affected phone passes this gate using the
Apple-delivered internal TestFlight build.

## Data boundary

- Do not uninstall, offload, downgrade, clear app data, reset Keychain, or
  repeatedly press Retry.
- Do not copy the User/Substrate databases, app container, wallet identifiers,
  Keychain values, or raw device logs without separate explicit approval.
- Capture only installed bundle/version metadata and process-filtered,
  privacy-sanitized Fearless startup messages.
- Keep the original `4.2.0 (2026.7.28)` app container intact until the safe log
  capture is complete and the internal TestFlight update is ready.

The host-side `scripts/filter-startup-syslog.py` filter accepts NDJSON from a
Fearless-process-only syslog stream. It writes timestamps, severity, safe
subsystem/category labels, and redacted startup messages; it never writes the
unfiltered input.

For distributed build `2026.7.28`, known source-derived error descriptions are
reduced to stable `legacy_incident_code`, `legacy_resolution`, and—only for a
low-space failure—the required free-byte count. Dynamic model/entity names,
paths, current free-space values, and unmatched error text are never retained.

## One `.28` diagnostic capture

Use `scripts/capture-testflight-startup.py`; do not pipe a broad device log to a
file. The supervisor requires the reviewed `pymobiledevice3` version `10.7.2`,
allows exactly one connected USB device, confirms the installed bundle/version,
and, after observing the new Fearless PID, requests only that PID from the
device's log service. The request uses `PROCESS_ONLY` and `NO_SENSITIVE` and
does not request historical logs, broad device logs, or call stacks. Its raw
stdout connects directly to the sanitizer through an OS pipe. Device identifiers
and process IDs remain in memory and are never published.

Choose a new absolute output directory and run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 \
  scripts/capture-testflight-startup.py \
  --pymobiledevice3 /ABSOLUTE/PATH/TO/PINNED-10.7.2/pymobiledevice3 \
  --expected-build 2026.7.28 \
  --output-directory /ABSOLUTE/NEW/PRIVATE/CAPTURE-DIRECTORY
```

The safe operator sequence is:

1. Connect, unlock, and Trust/Pair the affected phone. The tool waits without
   reading the app container. Do not open TestFlight or permit an automatic app
   update before the `.28` capture; the tool rechecks the installed identity at
   arm, launch, and finalization and aborts if it changes.
2. If `FEARLESS_CAPTURE_WAITING_FOR_FORCE_QUIT` appears, force-quit Fearless
   once and leave it closed.
3. Only after `FEARLESS_CAPTURE_ARMED` appears, cold-launch Fearless exactly
   once. Do not press Retry.
4. Wait for `FEARLESS_CAPTURE_COMPLETE`. A disconnect after the stopped
   boundary, a second launch, duplicate ready marker, wrong process envelope,
   wrong installed build, or sanitizer failure aborts the window.

Only `installed-app-metadata.json`, privacy-safe NDJSON, and a capture receipt
are produced on success. `captureStatus=complete` proves capture integrity;
`devicePIDStreamStartAcknowledged=true` proves the device accepted the exact
PID-only stream even if Fearless emitted no qualifying log record;
`diagnosticSufficient=true` additionally means a deterministic privacy-safe
incident mapping was observed. A bare startup marker or process termination is
recorded but does not claim a cause. It does not qualify the hotfix for release.

The affected-phone capture is stored at
`build/diagnostics/startup-capture-2026.7.28-20260813T023458Z/`. Its receipt
SHA-256 is
`018e39b2b75191d9322f49535c17bffddbba3c4d65a927f6f3f3fbedd167f5d1`.
It contains one failed marker, no ready marker, and no observed process
termination. The failed marker followed the first retained startup/migration
record by about 205 milliseconds, which contradicts the 15/60-second timeout
paths for this launch. No stable incident code was present, so the `.28`
parameterless callback makes migration, preflight, wallet opening, and the
post-setup broken/unsupported route indistinguishable. Do not repeat the `.28`
capture or request raw logs/container data; use `.8.10` structured markers for
the next deterministic observation.

## Internal TestFlight gate

1. Confirm the installed identity is `jp.co.soramitsu.fearlesswallet`, version
   `4.2.0`, build `2026.7.28` before the update.
2. Assign build `2026.8.10` to an internal TestFlight group only.
3. Install it in place through Apple's TestFlight app. Do not remove the existing
   installation or clear any data.
4. Start the first sanitized Fearless-only window with the exact command below.
   If requested, force-quit once; cold-launch only after the armed marker. Do
   not tap Retry. A failure still finalizes after the short terminal grace, but
   a ready launch remains under exact-PID observation for five full minutes:

   ```bash
   PYTHONDONTWRITEBYTECODE=1 python3 \
     scripts/capture-testflight-startup.py \
     --pymobiledevice3 /ABSOLUTE/PATH/TO/PINNED-10.7.2/pymobiledevice3 \
     --expected-build 2026.8.10 \
     --observation-seconds 900 \
     --terminal-grace-seconds 2 \
     --ready-observation-seconds 300 \
     --output-directory /ABSOLUTE/NEW/PRIVATE/FIRST-HOTFIX-CAPTURE
   ```
5. Keep Fearless open and usable for at least five continuous minutes. A living
   process is not evidence of usability. Require:
   - no failure alert and no `FEARLESS_STARTUP_FAILED` marker;
   - exactly one `FEARLESS_STARTUP_READY` marker in this launch window;
   - successful PIN entry and a working wallet route;
   - unchanged wallet counts, logical store integrity, Keychain access, and
     settings access, recorded only as pass/fail attestations without values.
6. After the first capture completes, force-quit once more and use a new output
   directory for the second cold launch. Require exactly one ready marker, no
   failed marker/alert, successful PIN entry, and a working wallet route:

   ```bash
   PYTHONDONTWRITEBYTECODE=1 python3 \
     scripts/capture-testflight-startup.py \
     --pymobiledevice3 /ABSOLUTE/PATH/TO/PINNED-10.7.2/pymobiledevice3 \
     --expected-build 2026.8.10 \
     --observation-seconds 180 \
     --terminal-grace-seconds 2 \
     --ready-observation-seconds 5 \
     --output-directory /ABSOLUTE/NEW/PRIVATE/SECOND-HOTFIX-CAPTURE
   ```
7. Store only sanitized evidence under ignored `build/` output and audit it:

   The evidence's first- and second-launch timestamps, marker counts, and
   `captureReceiptSHA256` values must match these two capture bundles. The
   auditor reads the private receipts, metadata, and sanitized logs directly;
   it rejects an unbound receipt, a short READY window, a stopped process,
   duplicate/missing markers, raw-data fields, or artifact provenance drift.
   Bind the audit to the source commit embedded in the uploaded IPA, not to a
   later host-only diagnostics commit:

   ```bash
   chmod 600 build/testflight-2026.8.10-upgrade-usability.json
   upload_receipt=build/upload/4.2.0-2026.8.10-b723df5e6/testflight-internal-upload.json
   artifact_source_commit="$(jq -er '.artifactSourceCommit' "$upload_receipt")"
   PYTHONDONTWRITEBYTECODE=1 python3 \
     scripts/audit-testflight-upgrade-usability-gate.py \
     build/testflight-2026.8.10-upgrade-usability.json \
     --first-launch-capture-receipt \
       /ABSOLUTE/PRIVATE/FIRST-HOTFIX-CAPTURE/capture-receipt.json \
     --second-launch-capture-receipt \
       /ABSOLUTE/PRIVATE/SECOND-HOTFIX-CAPTURE/capture-receipt.json \
     --expected-artifact-source-commit "$artifact_source_commit"
   ```

The evidence schema is enforced by the audit's tests. It binds both the exact
`.28` base commit and the clean hotfix commit embedded in the artifact, plus
build identity, timestamps, marker counts, and boolean attestations. It must not
contain database counts, wallet names/addresses, keys, paths, or device IDs.
Run the privacy boundary self-tests before producing evidence:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/test-filter-startup-syslog.py
PYTHONDONTWRITEBYTECODE=1 python3 scripts/test-capture-testflight-startup.py
PYTHONDONTWRITEBYTECODE=1 python3 \
  scripts/test-audit-testflight-upgrade-usability-gate.py
```

## Release decision

Only after the audit passes may release review replace build `2026.7.28` in the
public beta group with `2026.8.10`. Uploading, assigning the internal group, and
changing the public beta group are external release operations and require the
normal App Store Connect authorization and review trail.
