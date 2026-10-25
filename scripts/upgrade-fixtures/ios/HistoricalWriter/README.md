# Historical 4.0.4 store and real Keychain replay

This is a **T2 historical-source writer**, not the 4.0.4 application binary or a signed upgrade qualification. It fills the first IC-01 gap: two public sr25519 mnemonic wallets, each with its historical linked Ethereum identity. The existing historical golden oracle supplies the independent public-key/address comparison; no RC code generates expected secrets.

`prepare.py` extracts exact source from app `195b0230743fa3c5fb74fbf05f4e4ee38b2d0bcf`, shared-features `53e0a4bbea854ab32e97392365c3e523b9a0dc66`, and SoraKeystore 1.0.1 commit `17d16225eefbd6ce1d141ddc7447065878e277e2`. It retains full original files, member hashes, and generated hashes. Imports are adapted for one app module; a narrow descriptor supplies the original String identifier alias and chainId/ecosystem fields read by the per-chain imports. Its initializer is harness glue, and the full registry is not replayed. The original import operation, secret writes, mapper bodies, model fields and Keychain implementation execute unchanged. Core Data classes are generated from the old v12 model. The UIKit shell and evidence dumping are harness code.

The writer uses the previously accepted old oracle's compiled libraries, not the RC dependency graph. Give `--oracle` a preserved run of `scripts/upgrade-matrix/ios-historical` from the root audit repository. Its input file contains the public fixture catalog, not reference answers. Preserve and verify that oracle's runtime/source manifests alongside this run.

## Run

Use an isolated owned simulator named `G5-Historical-*`, with no user wallet data. Both **iOS 26.5 and 27.0** are required for this slice. Never erase or replace another simulator.

1. Run `prepare.py --app-repo <ios-repo> --shared-repo <historical-shared-git-repo> --keystore-repo <historical-keystore-git-repo> --oracle <accepted-old-oracle-run> --output <new-writer-run>`.
2. Run `build.py --run-dir <new-writer-run>`. It refuses source and reused historical-library hash drift and retains compile commands/logs. Install `HistoricalWriter.app` with `simctl`, launch `jp.co.soramitsu.fearlesswallet.dev`, and wait for `Documents/historical-state.json`. Do not treat `writer-error.txt` or app launch alone as success. Preserve the whole Documents directory. The writer refuses to replace a completed snapshot.
3. Build the current `fearless.tests` scheme for testing, using the existing repository dependency contracts. Pass `CODE_SIGN_ENTITLEMENTS=<writer-run>/simulator-entitlements.plist` so the RC and old source shell have the same **simulator** application/keychain identity. The test build embeds this identity in the simulator executable. It is a fixture seam, not proof of team, distribution, App Store or device entitlement continuity.
4. Run `qualify.py --simulator <id> --xctestrun <compiled-products>/fearless.tests_iphonesimulator27.0-arm64.xctestrun --golden <root-repo>/config/upgrade-matrix/expected/ios/4.0.4-source-195b023074.json --writer-run <writer-run> --output <new-qualification-run>` for each required runtime. It checks historical public identities, preserves the old store/snapshot, runs only `KeychainContinuityTests`, and requires the exact six named tests to pass once, zero failures/skips and the matching required runtime. It pins both the compiled app and XCTest bundle. It verifies the original store and snapshot remain byte-identical after the application replacement.

`KeychainContinuityTests` uses the production migration/model resolver, mapper, signing wrapper, verified phrase/seed readers, encrypted JSON exporter/decryptor, KeychainManager and PIN authenticator. It compares all 13 old secret records and access attributes. It deliberately reads a copy of the old SQLite file; the original is retained untouched. Its repeated-migration assertion covers a completed retry, not arbitrary process-kill boundaries.

The normal full suite explicitly skips these six externally prepared fixture tests when no old writer state exists. The G5 runner sets `FEARLESS_REQUIRE_HISTORICAL_KEYCHAIN=1`, so absent data fails, and separately rejects any skipped test count. A full-suite skip does not satisfy a G5 cell.

## Limits

- U1/U2 cover these two ordinary-name wallets and default root/linked accounts. Other names, curves, per-chain accounts, JSON/seed imports, TON, other releases, private/public shipped-schema variants and complete inventory remain separate requirements.
- U3 signs only `fearless-upgrade-matrix-v1|ios|IC-01`, never a transaction. Verification is local; no chain request is made.
- U4 compares mnemonic and stored raw seed bytes, and decrypts exported JSON before comparing its exact secret/public key. Ciphertext is randomized.
- U5 compares the historical tags, bytes, access group and `whenUnlockedThisDeviceOnly` protection across the old/RC application replacement.
- U6 is **partial**: wrong PIN rejected, same old PIN accepted, biometric preference retained, no PIN creation invoked. System biometric authentication, lock-state/accessibility behavior and physical-device entitlement continuity remain open.
- No T3 application UI, main startup, balance, signed/store, rollback, cloud or broad crash-safe qualification is claimed here.

## Additional curve and path profile

`--profile mnemonic-curves-paths-v1` on both `prepare.py` and `qualify.py` selects seven wallets: the two root controls, GW-M4 custom hardened/password paths on sr25519, ed25519 and ECDSA with Ethereum index 1, and both mandatory GW-M5 sr25519 soft variants. Use new owned simulators to preserve an earlier writer's state. The exact expected inventory is seven wallets and 48 unique Keychain records.

The writer emits SS58 addresses using the historical address factory. The reader compares those addresses and original curve/path/public-key fields, verifies all 14 account signatures locally, and compares phrase, seed and decrypted JSON exports. The runner separately compares all four mandatory GW-M5 outputs and the available GW-M4 entries against the accepted historical oracle. The additional GW-M4 ECDSA/password combination lacks an entry in that golden catalog: it is tested against the exact historical writer's stored identity, without claiming an independent pre-existing golden value.

This profile adds bounded IC-02 and soft-junction coverage. It does not exercise raw-seed-only or JSON-only import, per-chain records, legacy SubstrateData variants or full U6. The original `mnemonic-roots-v1` inventory remains supported; its frozen qualification artifacts are unchanged.

## Raw-seed-only profile

`--profile raw-seeds-v1` selects GW-S1 sr25519 and ed25519 without Ethereum, plus a third wallet combining the exact GW-S1 seed with GW-S2's separate Ethereum private key at the empty derivation path. The actual historical `MetaAccountImportSeedRequest` implementation writes three wallets and nine Keychain records. No entropy or phrase is inserted. Expected public identities come from the accepted historical golden catalog.

The reader requires the absent Ethereum accounts to remain absent, verifies four offline signatures, and compares exact seed and decrypted JSON exports. It also requires phrase export to return the actual missing-phrase error, refuses an empty backup proof, and checks that no entropy tag was created. This is bounded IC-03 coverage, not JSON-only import, application recovery UI, every seed/path variant or full U6.

## Encrypted JSON-only profile

`--profile json-only-v1` imports the three exact retained GW-J1 encrypted sr25519, ed25519 and ECDSA JSON files produced by the accepted historical oracle. `prepare.py` pins their original bytes and embeds their exact UTF-8 content in inputs; `build.py` rejects input or original-file drift. The historical `MetaAccountImportKeystoreRequest` implementation creates three wallets with only three secret keys, plus the historical PIN: four real Keychain records. No phrase or raw-seed tag is inserted.

Actual old imports reject the wrong and NFD-normalized public passwords, and reject the retained Ethereum V3 file as a linked import. The writer checks the whole application-accessible Keychain key inventory before and after each failed operation. These negative results are required by the runner; Ethereum V3 is not counted as a successfully imported historical wallet.

The current reader verifies three offline signatures and exact decrypted JSON exports. Phrase export must remain unavailable for all three. sr25519 raw-seed export must report missingSeed; ed25519/ECDSA may export the verified stored secret as the already-derived seed, without inventing a raw-seed tag. This is bounded IC-04 secret-only continuity, not application recovery UI, every JSON format or full U6.

## Per-chain mixed-import profile

`--profile per-chain-v1` starts with GW-M1's root mnemonic wallet, then executes the exact old per-chain import operations for GW-M2 sr25519 on Kusama, GW-S1 ed25519 seed on Westend, the original encrypted GW-J1 ECDSA JSON on Rococo, and GW-M2's default Ethereum path on Moonriver. Four distinct chain records coexist with the original root Substrate and Ethereum accounts. This profile uses the catalog's GW-P1 PIN `135790`; earlier profiles retain their frozen PINs.

The descriptor is deliberately narrow: the original `ChainModel` declarations for `chainId`, `ecosystem` and `Id` are retained, with a harness initializer. Those are the only descriptor fields read by the unchanged historical import bodies. `prepare.py` retains the full old `ChainModel.swift` and `Chain.swift`, pins the original declarations and genesis-hash member, and checks each configured chain identifier against that member. This is not a replay of the old remote registry, connection or application UI.

The old imports replace wallet-level seed tags. The writer records the actual root seed bytes before those writes and each child's export seed immediately after its own import. It does not repair the old Keychain. Four child records and 14 unique Keychain entries are preserved, including the overwritten root seed values. Current production verified readers must recover the exact original root seeds against the original root identities; failure remains a finding, never a substituted expectation. The reader checks every root and child identity, six offline signatures, account-scoped phrase availability, exact seed and decrypted JSON export, and rejection of whole-wallet backup proof for this mixed phrase/seed/JSON inventory. Both migrated and repeated-migration reads must leave the retained old store and all Keychain bytes/access attributes unchanged.

These are bounded IC-05/TM-I2 checks for this public mixed inventory on the required 26.5 and 27.0 simulators. U6 remains partial; no system biometric, physical/store entitlement, complete import UI, arbitrary legacy SubstrateData variant, network catalog or transaction qualification is implied.

## Native TON typed-phrase profile

`--profile ton-typed-v1` executes the old native TON import for GW-T1 and all six GW-T2 typed variants. The old operation derives from `components(separatedBy: " ")` and saves the exact UTF-8 phrase under the entropy tag, plus a 64-byte native TON secret. Its executed body is unchanged; the standalone module only removes `SSFModels.` from the operation's return type, with the original member/body hashes and adaptation recorded. Original request, constants and error declarations are retained.

The seven wallets have fourteen secret/phrase records plus GW-P1's PIN. A sixteenth, empty-tag key is an **explicit compatibility probe**: the harness passes the public GW-S1 seed to the old `saveSeed(... ecosystem: .ton)` helper, which obtains `""` from the actual old tag function and writes through the old Keychain implementation. The normal TON import does not invoke that helper; no normal historical import side effect or shipped empty-tag origin is claimed. The record must remain untouched during current reads/migration.

The current-reader checks compare exact old TON address JSON, v4R2 identity and every phrase byte against the accepted historical oracle. U3 uses production native TON signing credentials and the native Ed25519 primitive for a fixed offline message; it does not use the Substrate signing wrapper or build/broadcast a transaction. Native TON only offers its verified phrase export: no fabricated BIP39 seed or encrypted JSON export is credited. A healthy stored key with unavailable exact phrase export is a failing finding. U6 and distribution/physical/UI/legacy-schema limits remain as above.
