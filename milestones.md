# Fearless iOS Milestones

| Status | Milestone | Notes | Owner / Next Steps |
| --- | --- | --- | --- |
| ✅ | TON balance infrastructure landed | Toggle-driven TON env switch, TonAPI assembly boot, jetton injector, TonRemoteBalanceFetching, and assemblies wiring (commit 7c3eda9) | TON flows now display balances; continue with TonConnect work once Polkadot work stabilises. |
| ✅ | Shared-features-spm pin hardened | Repo, docs, and tooling now enforce `b820bfd` to stay aligned with `polkadot-stable2503`; SPM mirrors + manifest patches keep resolution deterministic | Monitor upstream for the next blessed revision; rerun `scripts/dev-setup.sh` after bumps. |
| ⏳ | Polkadot SDK `polkadot-stable2503` alignment | Dependencies bumped, but runtime/type bundles and staking flows still need validation against the new release | Refresh chain/type JSONs, smoke-test relay staking, fix SCALE regressions before marking complete. |
| ⏳ | Relay-chain staking regression suite | Needs dedicated verification (validators, bonding, payouts) on Polkadot/Kusama under the new runtime metadata | After runtime refresh, run `scripts/test-matrix.sh` plus manual staking flows; capture fixes + tests. |
| 🔜 | TonConnect v2 integration | No client/session plumbing yet; UX should reuse WalletConnect patterns while modernising that stack | Pick TonConnect SDK, design approval UI, wire signing adapters and session persistence. |
| 🔜 | Repo & utilities cleanup | Goal: trim duplication, enforce mirrors, document setup, and reduce flaky tooling | Audit scripts, remove unused deps, add CI checks for mirrors, and capture follow-up issues. |

Legend: ✅ Completed · ⏳ In progress · 🔜 Planned
