## Chain Registry Sources

Since the app took its configuration into this repository (#1305), release builds read the chain lists and chain types
from `remote-config/` here, through `https://raw.githubusercontent.com/soramitsu/fearless-iOS/master/remote-config/`
(`ApplicationConfig.chainsSourceUrl`, `chainTypesSourceUrl`). Values as of 2026-10-29:

| Artifact | Path | Size (bytes) | SHA256 |
| --- | --- | ---: | --- |
| Prod chains list | `remote-config/production/chains/v13/chains.json` | 300,939 | `373462d72052835bd02bf38018cb83478194bed96759c542120773aaae35d37b` |
| Dev chains list | `remote-config/development/chains/v13/chains_dev.json` | 332,518 | `97da306bd729c9b571d4483a9258210d425c6abe32da06d7a2ef721e26f508d4` |
| Prod chain types | `remote-config/production/chains/all_chains_types.json` | 415,606 | `ced6c59d8fb198dada4f43994fb5c3d9ea7109a5f691cc278ead97bcc7fcb90e` |
| Dev chain types | `remote-config/development/chains/all_chains_types.json` | 408,802 | `d270d62d4f9a0f1c0bacea7bb7909df513d083ee600ec76fbd41b04f55893d2d` |

`CrossChainOwnedRemoteConfigTests` checks the production chain list and XCM files against the compiled cross-chain
route registry, and `config/remote-config-imports.json` records each file's import and every later correction.

### Upstream snapshots (Polkadot stable2503)

Captured via `scripts/tools/chain-registry-check.sh` on `2026-03-19T14:42:04Z`, when the app still read
`soramitsu/shared-features-utils`. That repository is archived and the app no longer reads it.

| Artifact | Source | Size (bytes) | SHA256 | ETag |
| --- | --- | ---: | --- | --- |
| Prod chains list | https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/chains/v13/chains.json | 303,182 | `fa6f0e23cd87dfb3e5536980591dd22ae30e49bf59d04dc2a0b31fc53237ea66` | `46a810607d2dad144c2f6806c4f76b491aa99a62f7ffb7cc7ec9b2b70e8066f8` |
| Dev chains list | https://raw.githubusercontent.com/soramitsu/shared-features-utils/develop-free/chains/v13/chains_dev.json | 339,428 | `3511a9c314810fa93488b14b3b286ccdf2ac4402fd0081bde806fd9dd115b474` | `e9436a8df18b8cf4c1f26361f7799766f6b186a60e2512d91c475e5406099c3c` |
| Chain types | https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/chains/all_chains_types.json | 415,606 | `ced6c59d8fb198dada4f43994fb5c3d9ea7109a5f691cc278ead97bcc7fcb90e` | `d28c759a7dbb14f1a75940f50ac88f3332c5f47c8eb097c6eee80664e9d76f09` |

Keep the first table updated whenever the owned registry changes so later diffs and runtime alignment can be checked
quickly.
