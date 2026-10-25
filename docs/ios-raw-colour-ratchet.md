# Raw-colour adoption ratchet

`python3 scripts/check-raw-colours.py` scans live production Swift sources under
`fearless/`. It rejects new direct `UIColor(red:` or `UIColor(hex:` calls outside
`fearless/Common/DesignSystem/`. Whitespace and multiline arguments are recognized;
complete balanced argument text, its containing source lines, path and occurrence
count identify each exception. Comments are intentionally scanned too. This is a
conservative source-text rule, not a Swift syntax parser.

The initial exact inventory is 30 occurrences / 29 source contexts / 20 files,
pinned to the shared original iOS ancestor
`9415f7f7b8f37b1807229655c300f7d40e32d7fe`. Replaying the same rule against the later
lane observation `0ceddd35436633f03450a4ffdbac8c6382800fb8` gives the same counts. The plan's
older estimate of about 116 code literals had no supplied exact site inventory or
counting implementation. These counts do **not** establish retirement of that debt.
Wrapper functions, named system colours, SwiftUI constructors and xib colours are
outside this deliberately bounded rule. No production colour changes here.

`design/fw.raw-colour-baseline.ios.json` is exact, never a whole-file exception.
Removed sites must be deleted from the baseline. Increasing a count, changing a
colour or context, moving a site, or restoring an already-retired exception fails.
Migration should introduce a semantic role in the theme and remove its exception.
Initial adoption requires the anchor to precede both HEAD and the actual comparison
base, then checks every exception against that ancestor's actual Git source. A new
anchor committed inside a review branch cannot grandfather additions. Later
comparisons require the baseline's original source identity to stay
unchanged and its inventory only to shrink.

Local checks compare against `HEAD`; use `--base-ref COMMIT` to check a branch
against its review base. GitHub Actions compares against the PR base SHA, push
before SHA, or `HEAD^` for manual dispatch, with complete history fetched. Jenkins
uses explicit `FW_COLOUR_BASE_REF`, otherwise the fetched `CHANGE_TARGET` ref, or
`GIT_PREVIOUS_SUCCESSFUL_COMMIT`. A missing/unresolvable CI base fails; a first
Jenkins build must supply a legitimate fetched comparison base. No network fetch
or silent source-only fallback occurs inside the checker.

The zero-dependency Python unit suite runs in CI and the local test matrix. The
matrix invokes the live guard before dependency cleanup or Xcode, so compiled-test
caches cannot skip it. It intentionally runs on the host, where current repository
files and Git history are available, rather than bundling a stale source snapshot
into simulator XCTest. Run:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 scripts/test-check-raw-colours.py -v
PYTHONDONTWRITEBYTECODE=1 python3 scripts/check-raw-colours.py --base-ref HEAD
```

The guard does not prove screen contrast, token adoption, typography or release
readiness. The separate native UIKit contrast suite covers its declared contract.
