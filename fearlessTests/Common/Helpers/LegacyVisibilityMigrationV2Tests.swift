import BigInt
import CoreData
import CryptoKit
import SoraKeystore
import XCTest
@testable import fearless
import SSFModels

/// IOSUX-6: upgrade paths for asset visibility. The fixtures in `LegacyVisibility/` hold the rows App
/// Store 4.0.4, 3.6-3.7.4 and TestFlight 2026.9.x wrote, produced by `generate.py`, which re-implements
/// those writers over the reviewed registry snapshot, and the "shipped store" tests take the same rows
/// through the Core Data models and store migrations that shipped. Core property: legacy data never
/// hides a funded asset, except a hide the user made themselves (a TON wallet's rows, a TestFlight
/// choice), which stays Hidden.
final class LegacyVisibilityMigrationV2Tests: XCTestCase {
    private static let registrySnapshotSha256 = "fa6f0e23cd87dfb3e5536980591dd22ae30e49bf59d04dc2a0b31fc53237ea66"
    private static let fixtureNames = [
        "404-regular-scanned",
        "374-migrator",
        "v9-asset-ids-enabled",
        "404-ton-optout",
        "404-auto-hidden-then-funded",
        "testflight-v1-applied",
        "testflight-new-wallet"
    ]

    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "LegacyVisibilityMigrationV2Tests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        super.tearDown()
    }

    // MARK: - Every fixture

    func testFundedAssetIsNeverHiddenByLegacyData() throws {
        for name in Self.fixtureNames {
            let scenario = try LegacyVisibilityScenario(fixture: name, userDefaults: userDefaults)
            scenario.applyTestFlightState()
            scenario.migrate()

            let deliberateHides = Set(scenario.fixture.userHidden ?? []).union(
                (scenario.fixture.postUpgradeChoices ?? [:]).filter { $0.value == "hidden" }.keys
            )
            var fundedCount = 0
            for chainAsset in scenario.catalog where scenario.isFunded(chainAsset) {
                fundedCount += 1
                let expected: PortfolioPlacement = deliberateHides.contains(chainAsset.identifier) ? .hidden : .visible
                XCTAssertEqual(scenario.placement(for: chainAsset), expected, "\(name): \(chainAsset.identifier)")
            }
            XCTAssertEqual(fundedCount, scenario.fixture.balances.count, "\(name): every funded row resolves")
        }
    }

    func testNoTestnetIsVisibleAfterAnyUpgrade() throws {
        for name in Self.fixtureNames {
            let scenario = try LegacyVisibilityScenario(fixture: name, userDefaults: userDefaults)
            scenario.applyTestFlightState()
            scenario.migrate()

            let visibleTestnets = scenario.catalog.filter {
                PortfolioTestnetChainList.bundled.isTestnet($0.chain) && scenario.placement(for: $0) == .visible
            }
            XCTAssertEqual(visibleTestnets.map(\.identifier), [], name)
        }
    }

    func testMigrationIdempotent() throws {
        for name in Self.fixtureNames {
            let scenario = try LegacyVisibilityScenario(fixture: name, userDefaults: userDefaults)
            scenario.applyTestFlightState()

            XCTAssertFalse(scenario.migrate().isEmpty, name)
            let firstState = scenario.storedState()

            XCTAssertEqual(scenario.migrate(), [], name)
            XCTAssertEqual(scenario.storedState(), firstState, name)
        }
    }

    func testLegacyArrayNeverMutatedAndTheMappingCanBeRederived() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "404-regular-scanned", userDefaults: userDefaults)
        let legacyRows = scenario.wallet.assetsVisibility

        scenario.migrate()
        let hints = AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: scenario.wallet.metaId, userDefaults: userDefaults)

        XCTAssertEqual(scenario.wallet.assetsVisibility, legacyRows)
        XCTAssertEqual(legacyRows, scenario.fixture.wallet.assetsVisibility.map { AssetVisibility(assetId: $0.assetId, hidden: $0.hidden) })

        let rerun = try LegacyVisibilityScenario(
            fixture: "404-regular-scanned",
            userDefaults: userDefaults,
            metaId: "rederived"
        )
        rerun.migrate()
        XCTAssertEqual(
            AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: "rederived", userDefaults: userDefaults),
            hints
        )
    }

    // MARK: - Regular wallets

    func testRegular404NoExplicitPrefsWrittenFundedVisibleZeroCollapsed() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "404-regular-scanned", userDefaults: userDefaults)

        scenario.migrate()

        XCTAssertTrue(scenario.explicitPreferences().isEmpty)
        let hints = AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: scenario.wallet.metaId, userDefaults: userDefaults)
        let hiddenRows = scenario.fixture.wallet.assetsVisibility.filter(\.hidden).compactMap { scenario.asset($0.assetId) }
        XCTAssertGreaterThan(hiddenRows.count, 300)
        // Acala, Karura and Bifrost list two rows with one runtime currency id, so
        // a few rows share an AssetKey.
        XCTAssertEqual(hints.count, Set(hiddenRows.map(\.assetKey)).count)
        XCTAssertTrue(hiddenRows.allSatisfy { hints.contains($0.assetKey) })

        // The six holdings. Zero ranked assets were hidden by the 4.0.4 scan and stay out until
        // funded; Bitcoin and Solana get their zero rows once the first start adds their accounts
        // (contract §4: no zero row without an account).
        XCTAssertEqual(
            Set(scenario.visibleIdentifiers()),
            Set(scenario.fixture.balances.keys)
        )
    }

    func testRegular404ThroughThePortfolioFactory() throws {
        let metaId = "iosux6-factory-\(UUID().uuidString)"
        let scenario = try LegacyVisibilityScenario(
            fixture: "404-regular-scanned",
            userDefaults: .standard,
            metaId: metaId
        )
        defer { scenario.removeStoredState() }

        scenario.migrate()
        let build = { (accountInfos: [ChainAssetKey: AccountInfo?]) in
            ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
                .buildViewModel(
                    wallet: scenario.wallet,
                    chainAssets: scenario.catalog,
                    locale: Locale(identifier: "en_US"),
                    accountInfos: accountInfos,
                    chainsWithIssue: [],
                    shouldRunManageAssetAnimate: false,
                    displayType: .assetChains,
                    chainSettings: [],
                    networkFilter: nil,
                    search: nil
                )
        }
        let viewModel = build(scenario.accountInfos)

        let rows = viewModel.networkSections.flatMap(\.rows).map(\.chainAsset.identifier)
        XCTAssertEqual(Set(rows), Set(scenario.fixture.balances.keys))
        XCTAssertFalse(viewModel.networkSections.contains { $0.networkName == "Taira Testnet" || $0.networkName == "Westend" })
        // The 4.0.4 zero-hides leave no bare network headers behind (audit ADD-1).
        XCTAssertEqual(viewModel.networkSections.filter(\.rows.isEmpty).map(\.networkName), [])
        XCTAssertEqual(viewModel.networkSections.count, Set(viewModel.networkSections.flatMap(\.rows).map(\.chainAsset.chain.chainId)).count)

        // A deposit into an asset 4.0.4 had hidden at zero gets its row and its network back.
        let acala = try XCTUnwrap(scenario.asset(byNetwork: "Acala", symbol: "aca"))
        XCTAssertTrue(AssetVisibilityPreferenceStore.isLegacyZeroHidden(walletId: scenario.wallet.metaId, assetKey: acala.assetKey))
        XCTAssertFalse(rows.contains(acala.identifier))
        let account = try XCTUnwrap(scenario.wallet.fetch(for: acala.chain.accountRequest()))
        var funded = scenario.accountInfos
        funded[acala.uniqueKey(accountId: account.accountId)] = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 1, reserved: 0, frozen: 0, flags: 0)
        )
        let afterDeposit = build(funded)
        let acalaSection = try XCTUnwrap(afterDeposit.networkSections.first { $0.chainId == acala.chain.chainId })
        XCTAssertEqual(acalaSection.rows.map(\.chainAsset.identifier), [acala.identifier])
        XCTAssertEqual(afterDeposit.networkSections.filter(\.rows.isEmpty).map(\.networkName), [])
    }

    func testAutoHiddenThenFundedIsVisible() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "404-auto-hidden-then-funded", userDefaults: userDefaults)

        scenario.migrate()

        let pha = try XCTUnwrap(scenario.asset(byNetwork: "Phala", symbol: "pha"))
        let assetHubUsdt = try XCTUnwrap(scenario.asset(byNetwork: "Polkadot AssetHub", symbol: "usdt"))
        let kusama = try XCTUnwrap(scenario.asset(byNetwork: "Kusama", symbol: "ksm"))
        let hints = AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: scenario.wallet.metaId, userDefaults: userDefaults)

        XCTAssertTrue(scenario.explicitPreferences().isEmpty)
        XCTAssertTrue(hints.contains(pha.assetKey))
        XCTAssertTrue(hints.contains(assetHubUsdt.assetKey))
        XCTAssertEqual(scenario.placement(for: pha), .visible)
        XCTAssertEqual(scenario.placement(for: assetHubUsdt), .visible)
        // KSM was visible at zero in 4.0.4 (empty-wallet defaults) and is a listed zero default.
        XCTAssertFalse(hints.contains(kusama.assetKey))
        XCTAssertEqual(scenario.placement(for: kusama), .visible)
    }

    func testMigratorOutputBehavesLikeAScan() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "374-migrator", userDefaults: userDefaults)

        scenario.migrate()

        let kusama = try XCTUnwrap(scenario.asset(byNetwork: "Kusama", symbol: "ksm"))
        let polkadot = try XCTUnwrap(scenario.asset(byNetwork: "Polkadot", symbol: "dot"))
        XCTAssertTrue(scenario.explicitPreferences().isEmpty)
        XCTAssertEqual(scenario.placement(for: kusama), .visible)
        XCTAssertEqual(scenario.placement(for: polkadot), .zeroCollapsed, "hidden at zero by the migrator")
    }

    func testV9BareIdsOnlyProduceZeroHiddenHints() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "v9-asset-ids-enabled", userDefaults: userDefaults)

        scenario.migrate()

        let hints = AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: scenario.wallet.metaId, userDefaults: userDefaults)
        let polkadot = try XCTUnwrap(scenario.asset(byNetwork: "Polkadot", symbol: "dot"))
        let polkadotAssetHub = try XCTUnwrap(scenario.asset(byNetwork: "Polkadot AssetHub", symbol: "dot"))
        let kusama = try XCTUnwrap(scenario.asset(byNetwork: "Kusama", symbol: "ksm"))
        let kusamaAssetHub = try XCTUnwrap(scenario.asset(byNetwork: "Kusama AssetHub", symbol: "ksm"))
        let phala = try XCTUnwrap(scenario.asset(byNetwork: "Phala", symbol: "pha"))

        XCTAssertTrue(scenario.explicitPreferences().isEmpty)
        for chainAsset in [polkadot, polkadotAssetHub, kusama, kusamaAssetHub, phala] {
            XCTAssertTrue(hints.contains(chainAsset.assetKey), chainAsset.identifier)
        }
        XCTAssertEqual(scenario.placement(for: polkadot), .visible, "funded")
        XCTAssertEqual(scenario.placement(for: kusamaAssetHub), .visible, "funded")
        XCTAssertEqual(scenario.placement(for: kusama), .zeroCollapsed)
    }

    func testIncompleteCatalogDoesNotWriteMarker() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "v9-asset-ids-enabled", userDefaults: userDefaults)

        let changed = AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: scenario.wallet,
            chainAssets: scenario.catalog,
            catalogIsComplete: false,
            userDefaults: userDefaults
        )

        XCTAssertEqual(changed, [])
        XCTAssertNil(userDefaults.object(forKey: "asset.presentation.asset_key.migrated.v2:\(scenario.wallet.metaId)"))
        XCTAssertTrue(AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: scenario.wallet.metaId, userDefaults: userDefaults).isEmpty)

        XCTAssertFalse(scenario.migrate().isEmpty)
        XCTAssertFalse(AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: scenario.wallet.metaId, userDefaults: userDefaults).isEmpty)
    }

    func testChoiceMadeBeforeTheMigrationWins() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "404-regular-scanned", userDefaults: userDefaults)
        let kusama = try XCTUnwrap(scenario.asset(byNetwork: "Kusama", symbol: "ksm"))
        let acala = try XCTUnwrap(scenario.asset(byNetwork: "Acala", symbol: "aca"))
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: scenario.wallet.metaId, assetKey: kusama.assetKey, userDefaults: userDefaults)
        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: scenario.wallet.metaId, assetKey: acala.assetKey, userDefaults: userDefaults)

        scenario.migrate()

        let hints = AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: scenario.wallet.metaId, userDefaults: userDefaults)
        XCTAssertFalse(hints.contains(acala.assetKey))
        XCTAssertEqual(scenario.placement(for: kusama), .hidden)
        XCTAssertEqual(scenario.placement(for: acala), .visible)
    }

    func testUserChoiceReplacesTheLegacyHint() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "404-regular-scanned", userDefaults: userDefaults)
        let acala = try XCTUnwrap(scenario.asset(byNetwork: "Acala", symbol: "aca"))
        let walletId = scenario.wallet.metaId
        scenario.migrate()
        XCTAssertTrue(AssetVisibilityPreferenceStore.isLegacyZeroHidden(walletId: walletId, assetKey: acala.assetKey, userDefaults: userDefaults))

        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: walletId, assetKey: acala.assetKey, userDefaults: userDefaults)
        XCTAssertFalse(AssetVisibilityPreferenceStore.isLegacyZeroHidden(walletId: walletId, assetKey: acala.assetKey, userDefaults: userDefaults))
        XCTAssertEqual(scenario.placement(for: acala), .visible)

        // "Reset to automatic" leaves a plain Auto asset: Acala is not a zero default.
        AssetVisibilityPreferenceStore.setPreference(.auto, walletId: walletId, assetKey: acala.assetKey, userDefaults: userDefaults)
        XCTAssertFalse(AssetVisibilityPreferenceStore.isLegacyZeroHidden(walletId: walletId, assetKey: acala.assetKey, userDefaults: userDefaults))
        XCTAssertEqual(scenario.placement(for: acala), .zeroCollapsed)
    }

    // MARK: - TON wallets

    func testTonOptOutHidesStayHidden() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "404-ton-optout", userDefaults: userDefaults)
        let walletId = scenario.wallet.metaId

        scenario.migrate()

        let byName = Dictionary(grouping: scenario.extraAssets, by: { $0.asset.name })
        let jettonA = try XCTUnwrap(byName["Jetton A"]?.first { $0.asset.id != $0.asset.currencyId })
        let jettonARelease = try XCTUnwrap(byName["Jetton A"]?.first { $0.asset.id == $0.asset.currencyId })
        let jettonB = try XCTUnwrap(byName["Jetton B"]?.first)
        let jettonC = try XCTUnwrap(byName["Jetton C"]?.first)
        let jettonD = try XCTUnwrap(byName["Jetton D"]?.first)
        let ton = try XCTUnwrap(scenario.asset(byNetwork: "TON Mainnet", symbol: "ton"))
        let keptHidden = AssetVisibilityPreferenceStore.hiddenInPreviousVersion(walletId: walletId, userDefaults: userDefaults)

        XCTAssertEqual(jettonA.assetKey, jettonARelease.assetKey, "4.0.4 and release jetton rows share the master key")
        for jetton in [jettonA, jettonARelease, jettonB] {
            XCTAssertEqual(scenario.preference(jetton), .hidden, jetton.asset.name)
            XCTAssertEqual(scenario.placement(for: jetton), .hidden, jetton.asset.name)
        }
        XCTAssertTrue(keptHidden.contains(jettonA.assetKey))
        XCTAssertTrue(keptHidden.contains(jettonB.assetKey))
        XCTAssertEqual(keptHidden.count, 2)
        for asset in [jettonC, jettonD, ton] {
            XCTAssertEqual(scenario.preference(asset), .auto, asset.asset.name)
            XCTAssertEqual(scenario.placement(for: asset), .visible, asset.asset.name)
        }
        XCTAssertEqual(scenario.explicitPreferences().count, 2, "the vanished jetton E writes nothing")
        XCTAssertTrue(AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: walletId, userDefaults: userDefaults).isEmpty)

        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: walletId, assetKey: jettonA.assetKey, userDefaults: userDefaults)
        XCTAssertFalse(
            AssetVisibilityPreferenceStore.hiddenInPreviousVersion(walletId: walletId, userDefaults: userDefaults)
                .contains(jettonA.assetKey)
        )
    }

    func testTonChoiceMadeBeforeTheMigrationIsNotOverwritten() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "404-ton-optout", userDefaults: userDefaults)
        let jettonB = try XCTUnwrap(scenario.extraAssets.first { $0.asset.name == "Jetton B" })
        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: scenario.wallet.metaId, assetKey: jettonB.assetKey, userDefaults: userDefaults)

        scenario.migrate()

        XCTAssertEqual(scenario.preference(jettonB), .shown)
        XCTAssertFalse(
            AssetVisibilityPreferenceStore.hiddenInPreviousVersion(walletId: scenario.wallet.metaId, userDefaults: userDefaults)
                .contains(jettonB.assetKey)
        )
    }

    // MARK: - TestFlight

    func testTestFlightV1PrefsRevertedButPostUpgradeUserChoicesKept() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "testflight-v1-applied", userDefaults: userDefaults)
        let fixture = scenario.fixture
        let firstMigration = try XCTUnwrap(fixture.firstMigrationPreferences)
        let postUpgrade = try XCTUnwrap(fixture.postUpgradeChoices)
        let autoShown = try XCTUnwrap(fixture.autoShown)
        scenario.applyTestFlightState()

        scenario.migrate()

        let hints = AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: scenario.wallet.metaId, userDefaults: userDefaults)
        for (identifier, choice) in postUpgrade {
            let chainAsset = try XCTUnwrap(scenario.asset(identifier), identifier)
            XCTAssertEqual(scenario.preference(chainAsset).rawValue, choice, identifier)
            XCTAssertFalse(hints.contains(chainAsset.assetKey), identifier)
        }
        for (identifier, written) in firstMigration where postUpgrade[identifier] == nil {
            guard let chainAsset = scenario.asset(identifier) else {
                continue
            }
            XCTAssertEqual(scenario.preference(chainAsset), .auto, identifier)
            XCTAssertEqual(hints.contains(chainAsset.assetKey), written == "hidden", identifier)
        }
        // Shown the scans had stored on their own is nobody's choice.
        for identifier in autoShown where postUpgrade[identifier] == nil {
            let chainAsset = try XCTUnwrap(scenario.asset(identifier), identifier)
            XCTAssertEqual(scenario.preference(chainAsset), .auto, identifier)
        }
        // KSM is a ranked utility asset too, but the first migration had hidden it, so no scan
        // ever wrote there: its Shown can only be the user's and stays.
        let kusama = try XCTUnwrap(scenario.asset(byNetwork: "Kusama", symbol: "ksm"))
        XCTAssertEqual(firstMigration[kusama.identifier], "hidden")
        XCTAssertEqual(postUpgrade[kusama.identifier], "shown")
        XCTAssertEqual(scenario.preference(kusama), .shown)

        let acala = try XCTUnwrap(scenario.asset(byNetwork: "Acala", symbol: "aca"))
        XCTAssertEqual(firstMigration[acala.identifier], "hidden")
        XCTAssertEqual(scenario.placement(for: acala), .visible, "the first migration had kept it hidden")
        let taira = try XCTUnwrap(scenario.asset("iroha3-taira : 6TEAJqbb8oEPmLncoNiMRbLEK6tw"))
        XCTAssertEqual(scenario.placement(for: taira), .hidden)
    }

    func testTestFlightScanWrittenShownGoesBackToAutoButUserChoicesStay() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "testflight-new-wallet", userDefaults: userDefaults)
        let walletId = scenario.wallet.metaId
        let autoShown = try XCTUnwrap(scenario.fixture.autoShown)
        let choices = try XCTUnwrap(scenario.fixture.postUpgradeChoices)
        scenario.applyTestFlightState()

        // What the TestFlight build left behind: Shown on every ranked network's utility asset,
        // testnets included, none of it chosen by the user.
        XCTAssertGreaterThan(autoShown.count, 15)
        XCTAssertTrue(scenario.fixture.wallet.assetsVisibility.isEmpty)
        for identifier in autoShown where choices[identifier] == nil {
            XCTAssertEqual(scenario.preference(try XCTUnwrap(scenario.asset(identifier), identifier)), .shown, identifier)
        }

        scenario.migrate()

        for identifier in autoShown where choices[identifier] == nil {
            XCTAssertEqual(scenario.preference(try XCTUnwrap(scenario.asset(identifier), identifier)), .auto, identifier)
        }
        for (identifier, choice) in choices {
            XCTAssertEqual(scenario.preference(try XCTUnwrap(scenario.asset(identifier), identifier)).rawValue, choice, identifier)
        }
        XCTAssertEqual(scenario.explicitPreferences().count, choices.count, "only the user's own choices are left")
        XCTAssertTrue(AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: walletId, userDefaults: userDefaults).isEmpty)

        // The portfolio after the upgrade.
        let polkadot = try XCTUnwrap(scenario.asset(byNetwork: "Polkadot", symbol: "dot"))
        let acala = try XCTUnwrap(scenario.asset(byNetwork: "Acala", symbol: "aca"))
        let ethereum = try XCTUnwrap(scenario.asset(byNetwork: "Ethereum", symbol: "eth"))
        let kusama = try XCTUnwrap(scenario.asset(byNetwork: "Kusama", symbol: "ksm"))
        let westend = try XCTUnwrap(scenario.asset(byNetwork: "Westend", symbol: "wnd"))
        let wrappedOkb = try XCTUnwrap(scenario.asset(byNetwork: "X Layer Mainnet", symbol: "wokb"))
        let bitcoin = try XCTUnwrap(scenario.asset("bitcoin:mainnet : BTC"))
        let taira = try XCTUnwrap(scenario.asset("iroha3-taira : 6TEAJqbb8oEPmLncoNiMRbLEK6tw"))
        XCTAssertTrue(scenario.isFunded(polkadot))
        XCTAssertEqual(scenario.placement(for: polkadot), .hidden, "the user hid it; funded or not, it stays hidden")
        XCTAssertEqual(scenario.placement(for: acala), .visible, "the user switched it on at zero")
        XCTAssertEqual(scenario.placement(for: ethereum), .visible, "funded")
        XCTAssertEqual(scenario.placement(for: kusama), .visible, "a listed zero default, as before")
        XCTAssertEqual(scenario.placement(for: bitcoin), .zeroCollapsed, "no account yet, so no zero row")
        XCTAssertEqual(scenario.placement(for: taira), .hidden)
        XCTAssertEqual(scenario.placement(for: westend), .hidden)
        XCTAssertEqual(scenario.placement(for: wrappedOkb), .zeroCollapsed, "ranked, but not the network's zero default")

        // It runs once: a Show the user makes afterwards is theirs.
        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: walletId, assetKey: taira.assetKey, userDefaults: userDefaults)
        XCTAssertEqual(scenario.migrate(), [])
        XCTAssertEqual(scenario.preference(taira), .shown)
        XCTAssertEqual(scenario.placement(for: taira), .visible)
    }

    func testShownWithoutTheFirstMigrationMarkerIsAUserChoice() throws {
        // Only TestFlight builds stored the first-migration marker, and only they stored Shown from a
        // scan. On an App Store 4.0.4 upgrade or a fresh install every Shown is the user's.
        let scenario = try LegacyVisibilityScenario(fixture: "404-regular-scanned", userDefaults: userDefaults)
        let walletId = scenario.wallet.metaId
        let shown = [
            try XCTUnwrap(scenario.asset("iroha3-taira : 6TEAJqbb8oEPmLncoNiMRbLEK6tw")),
            try XCTUnwrap(scenario.asset("bitcoin:mainnet : BTC")),
            try XCTUnwrap(scenario.asset(byNetwork: "Westend", symbol: "wnd")),
            try XCTUnwrap(scenario.asset(byNetwork: "X Layer Mainnet", symbol: "wokb"))
        ]
        for chainAsset in shown {
            AssetVisibilityPreferenceStore.setPreference(.shown, walletId: walletId, assetKey: chainAsset.assetKey, userDefaults: userDefaults)
        }

        scenario.migrate()

        for chainAsset in shown {
            XCTAssertEqual(scenario.preference(chainAsset), .shown, chainAsset.identifier)
            XCTAssertEqual(scenario.placement(for: chainAsset), .visible, chainAsset.identifier)
        }
    }

    func testTestFlightStoredKeysAreReadByTheRelease() throws {
        // `storedPreferences` holds the UserDefaults keys as TestFlight 9415f7f7b derived them.
        for name in ["testflight-v1-applied", "testflight-new-wallet"] {
            let scenario = try LegacyVisibilityScenario(fixture: name, userDefaults: userDefaults)
            let preferences = try XCTUnwrap(scenario.fixture.preferences)
            XCTAssertFalse(try XCTUnwrap(scenario.fixture.storedPreferences).isEmpty)
            scenario.applyTestFlightState()

            XCTAssertEqual(scenario.explicitPreferences().count, scenario.fixture.storedPreferences?.count, name)
            let rowsPerKey = Dictionary(grouping: scenario.catalog, by: \.assetKey).mapValues(\.count)
            var checked = 0
            for (identifier, rawValue) in preferences {
                // Rows that share one runtime asset share one stored value; compare where the row
                // decides its key alone.
                guard let chainAsset = scenario.asset(identifier), rowsPerKey[chainAsset.assetKey] == 1 else {
                    continue
                }
                XCTAssertEqual(scenario.preference(chainAsset).rawValue, rawValue, "\(name): \(identifier)")
                checked += 1
            }
            XCTAssertGreaterThan(checked, 15, name)
        }
    }

    // MARK: - Through the observer

    /// TestFlight builds answered every scan by storing Shown for the ranked networks' utility
    /// assets. The release's scan stores nothing, and the observer runs the migration before it.
    func testScanThroughTheObserverUndoesScanWrittenShownAndStoresNothing() async throws {
        let scenario = try LegacyVisibilityScenario(fixture: "testflight-new-wallet", userDefaults: .standard)
        defer { scenario.removeStoredState() }
        let choices = try XCTUnwrap(scenario.fixture.postUpgradeChoices)
        scenario.applyTestFlightState()
        XCTAssertGreaterThan(scenario.explicitPreferences().count, 15)
        let events = VisibilityEventRecorder()
        let discovery = FundedDiscoveryStub(scenario: scenario)
        let observer = WalletAssetsObserverImpl(
            wallet: scenario.wallet,
            chainRegistry: MockChainRegistryProtocol(),
            assetDiscoveryService: discovery,
            eventCenter: events,
            logger: Logger.shared,
            userDefaultsStorage: InMemorySettingsManager(),
            chainCatalog: FixedChainCatalog(chains: scenario.chains)
        )

        // A Manage pull-to-refresh over every listed asset, testnets included.
        _ = await observer.updateVisibility(wallet: scenario.wallet, chainAssets: scenario.catalog)

        let westend = try XCTUnwrap(scenario.asset(byNetwork: "Westend", symbol: "wnd"))
        XCTAssertEqual(discovery.scannedChainIds.count, 1)
        XCTAssertTrue(
            try XCTUnwrap(discovery.scannedChainIds.first).contains(westend.chain.chainId),
            "the ranked testnets were scanned too"
        )
        let stored = scenario.explicitPreferences()
        XCTAssertEqual(stored.count, choices.count)
        for (identifier, choice) in choices {
            XCTAssertEqual(stored[try XCTUnwrap(scenario.asset(identifier)).assetKey]?.rawValue, choice, identifier)
        }
        XCTAssertEqual(events.visibilityEvents.count, 1, "one refresh for the whole migration")

        _ = await observer.updateVisibility(wallet: scenario.wallet, chainAssets: scenario.catalog)

        XCTAssertEqual(discovery.scannedChainIds.count, 2)
        XCTAssertEqual(scenario.explicitPreferences(), stored, "a later scan stores nothing either")
        XCTAssertEqual(events.visibilityEvents.count, 1)
    }

    func testScanThroughTheObserverLeavesAnAppStoreWalletOnAuto() async throws {
        let scenario = try LegacyVisibilityScenario(fixture: "404-regular-scanned", userDefaults: .standard)
        defer { scenario.removeStoredState() }
        let discovery = FundedDiscoveryStub(scenario: scenario)
        let observer = WalletAssetsObserverImpl(
            wallet: scenario.wallet,
            chainRegistry: MockChainRegistryProtocol(),
            assetDiscoveryService: discovery,
            eventCenter: VisibilityEventRecorder(),
            logger: Logger.shared,
            userDefaultsStorage: InMemorySettingsManager(),
            chainCatalog: FixedChainCatalog(chains: scenario.chains)
        )

        _ = await observer.updateVisibility(wallet: scenario.wallet, chainAssets: scenario.catalog)

        XCTAssertEqual(discovery.scannedChainIds.count, 1)
        XCTAssertTrue(scenario.explicitPreferences().isEmpty, "neither the migration nor the scan chooses for the user")
        XCTAssertFalse(
            AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: scenario.wallet.metaId).isEmpty,
            "the observer ran the migration"
        )
        XCTAssertEqual(
            Set(scenario.visibleIdentifiers()),
            Set(scenario.fixture.balances.keys)
        )
    }

    // MARK: - Shipped stores

    /// The 4.0.4 rows as its Core Data model (ecosystem line, v12) stored them, taken through the
    /// release's own store migration and wallet mapper before the visibility migration reads them.
    func testAppStore404StoreRowsReachTheMigrationThroughTheStoreUpgrade() throws {
        let fixture = try LegacyVisibilityScenario.loadFixture("404-regular-scanned")
        let rows = fixture.wallet.assetsVisibility.map { AssetVisibility(assetId: $0.assetId, hidden: $0.hidden) }
        let wallet = try ShippedUserStore.upgradedWallet(from: .version13) { wallet, context, model in
            for row in rows {
                let entity = try XCTUnwrap(model.entitiesByName["CDAssetVisibility"])
                let visibility = NSManagedObject(entity: entity, insertInto: context)
                visibility.setValue(row.assetId, forKey: "assetId")
                visibility.setValue(row.hidden, forKey: "hidden")
                visibility.setValue(wallet, forKey: "wallet")
            }
        }

        XCTAssertEqual(wallet.assetsVisibility.count, rows.count)
        XCTAssertEqual(Set(wallet.assetsVisibility), Set(rows), "the store upgrade keeps every row as written")

        let scenario = try LegacyVisibilityScenario(
            fixture: "404-regular-scanned",
            userDefaults: userDefaults,
            wallet: wallet
        )
        scenario.migrate()

        XCTAssertTrue(scenario.explicitPreferences().isEmpty)
        XCTAssertEqual(scenario.wallet.assetsVisibility, wallet.assetsVisibility)
        XCTAssertEqual(
            Set(scenario.visibleIdentifiers()),
            Set(fixture.balances.keys),
            "the six holdings; nothing 4.0.4 hid at zero comes back"
        )
        XCTAssertEqual(scenario.fundedCount, fixture.balances.count)
    }

    /// A 3.x store (v8 model) whose `assetIdsEnabled` list the shipped V9 policy turns into hidden
    /// rows on the way to the current model.
    func testV8AssetIdsEnabledStoreBecomesZeroHiddenHintsThroughTheShippedPolicy() throws {
        let fixture = try LegacyVisibilityScenario.loadFixture("v9-asset-ids-enabled")
        let assetIdsEnabled = fixture.wallet.assetsVisibility.map(\.assetId)
        XCTAssertTrue(fixture.wallet.assetsVisibility.allSatisfy(\.hidden))
        let wallet = try ShippedUserStore.upgradedWallet(from: .version9) { wallet, _, _ in
            wallet.setValue(assetIdsEnabled as NSArray, forKey: "assetIdsEnabled")
        }

        // The generator's port of the policy and the policy itself agree.
        XCTAssertEqual(
            Set(wallet.assetsVisibility),
            Set(assetIdsEnabled.map { AssetVisibility(assetId: $0, hidden: true) })
        )

        let scenario = try LegacyVisibilityScenario(
            fixture: "v9-asset-ids-enabled",
            userDefaults: userDefaults,
            wallet: wallet
        )
        scenario.migrate()

        let hints = AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: wallet.metaId, userDefaults: userDefaults)
        let polkadot = try XCTUnwrap(scenario.asset(byNetwork: "Polkadot", symbol: "dot"))
        let kusamaAssetHub = try XCTUnwrap(scenario.asset(byNetwork: "Kusama AssetHub", symbol: "ksm"))
        let kusama = try XCTUnwrap(scenario.asset(byNetwork: "Kusama", symbol: "ksm"))
        XCTAssertTrue(scenario.explicitPreferences().isEmpty)
        XCTAssertTrue(hints.contains(polkadot.assetKey))
        XCTAssertTrue(hints.contains(kusama.assetKey))
        XCTAssertEqual(scenario.placement(for: polkadot), .visible, "funded")
        XCTAssertEqual(scenario.placement(for: kusamaAssetHub), .visible, "funded")
        XCTAssertEqual(scenario.placement(for: kusama), .zeroCollapsed)
        XCTAssertEqual(scenario.fundedCount, fixture.balances.count)
    }

    func testFixturesWereGeneratedFromTheReviewedRegistry() throws {
        for name in Self.fixtureNames {
            let fixture = try LegacyVisibilityScenario.loadFixture(name)
            XCTAssertEqual(fixture.format, "fearless.ios-legacy-visibility-fixture", name)
            XCTAssertEqual(fixture.registrySha256, Self.registrySnapshotSha256, name)
            XCTAssertEqual(fixture.id, name)
        }
    }
}

// MARK: - Fixture model

struct LegacyVisibilityFixture: Decodable {
    struct Wallet: Decodable {
        struct Row: Decodable {
            let assetId: String
            let hidden: Bool
        }

        let ecosystem: String
        let legacyTon: Bool
        let accounts: [String]
        let assetsVisibility: [Row]
    }

    struct ExtraAsset: Decodable {
        let chainId: String
        let id: String
        let currencyId: String
        let symbol: String
        let name: String
        let precision: UInt16
    }

    let format: String
    let id: String
    let registrySha256: String
    let wallet: Wallet
    let balances: [String: String]
    let extraAssets: [ExtraAsset]?
    let userHidden: [String]?
    let firstMigrationMarker: Bool?
    let firstMigrationPreferences: [String: String]?
    let autoShown: [String]?
    let postUpgradeChoices: [String: String]?
    let preferences: [String: String]?
    /// UserDefaults key suffixes ("ecosystem:chainId:assetId") and raw values as the TestFlight
    /// builds stored them.
    let storedPreferences: [String: String]?
}

/// One fixture wallet on one device: the catalog the release reads (registry snapshot, app-owned
/// networks and any jettons the fixture declares), the wallet as the release decodes it, and the
/// fixture balances.
final class LegacyVisibilityScenario {
    let fixture: LegacyVisibilityFixture
    let wallet: MetaAccountModel
    let chains: [ChainModel]
    let catalog: [ChainAsset]
    let extraAssets: [ChainAsset]
    let accountInfos: [ChainAssetKey: AccountInfo?]
    private let userDefaults: UserDefaults
    private let byIdentifier: [String: ChainAsset]

    /// - Parameter wallet: a wallet read back from a store, in place of the generated one.
    init(
        fixture name: String,
        userDefaults: UserDefaults,
        metaId: String = UUID().uuidString,
        wallet storedWallet: MetaAccountModel? = nil
    ) throws {
        let fixture = try Self.loadFixture(name)
        self.fixture = fixture
        self.userDefaults = userDefaults

        let chains = try Self.registryChains()
        var extraAssets: [ChainAsset] = []
        for extra in fixture.extraAssets ?? [] {
            let chain = try XCTUnwrap(chains.first { $0.chainId == extra.chainId })
            let asset = AssetModel(
                id: extra.id,
                name: extra.name,
                symbol: extra.symbol,
                precision: extra.precision,
                icon: nil,
                price: nil,
                fiatDayChange: nil,
                currencyId: extra.currencyId,
                existentialDeposit: nil,
                color: nil,
                isUtility: false,
                isNative: false,
                staking: nil,
                purchaseProviders: nil,
                type: nil,
                ethereumType: nil,
                priceProvider: nil,
                coingeckoPriceId: nil
            )
            chain.assets.insert(asset)
            extraAssets.append(ChainAsset(chain: chain, asset: asset))
        }
        self.extraAssets = extraAssets
        self.chains = chains
        catalog = chains.flatMap(\.chainAssets)
        byIdentifier = Dictionary(catalog.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })

        let rows = fixture.wallet.assetsVisibility.map { AssetVisibility(assetId: $0.assetId, hidden: $0.hidden) }
        if let storedWallet {
            wallet = storedWallet
        } else if fixture.wallet.legacyTon {
            wallet = try MetaAccountModel(
                metaId: metaId,
                name: "Released native TON",
                substrateAccountId: nil,
                substrateCryptoType: CryptoType.ed25519.rawValue,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                assetKeysOrder: nil,
                canExportEthereumMnemonic: true,
                unusedChainIds: nil,
                selectedCurrency: Currency.defaultCurrency(),
                networkManagmentFilter: "-239",
                assetsVisibility: rows,
                hasBackup: false,
                favouriteChainIds: [],
                legacyTonAccount: LegacyNativeTonFixture.account()
            )
        } else {
            XCTAssertEqual(Set(fixture.wallet.accounts), ["substrate", "evm"])
            let generated = AccountGenerator.generateMetaAccount()
            wallet = MetaAccountModel(
                metaId: metaId,
                name: generated.name,
                substrateAccountId: generated.substrateAccountId,
                substrateCryptoType: generated.substrateCryptoType,
                substratePublicKey: generated.substratePublicKey,
                ethereumAddress: generated.ethereumAddress,
                ethereumPublicKey: generated.ethereumPublicKey,
                chainAccounts: [],
                assetKeysOrder: nil,
                canExportEthereumMnemonic: true,
                unusedChainIds: nil,
                selectedCurrency: Currency.defaultCurrency(),
                networkManagmentFilter: nil,
                assetsVisibility: rows,
                hasBackup: true,
                favouriteChainIds: []
            )
        }

        var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
        for (identifier, planks) in fixture.balances {
            guard let chainAsset = byIdentifier[identifier],
                  let account = wallet.fetch(for: chainAsset.chain.accountRequest()),
                  let amount = BigUInt(planks) else {
                continue
            }
            accountInfos[chainAsset.uniqueKey(accountId: account.accountId)] = AccountInfo(
                nonce: 0,
                consumers: 0,
                providers: 0,
                data: AccountData(free: amount, reserved: 0, frozen: 0, flags: 0)
            )
        }
        self.accountInfos = accountInfos
    }

    func asset(_ identifier: String) -> ChainAsset? {
        byIdentifier[identifier]
    }

    func asset(byNetwork network: String, symbol: String) -> ChainAsset? {
        catalog.first { $0.chain.name == network && $0.asset.symbol == symbol }
    }

    func isFunded(_ chainAsset: ChainAsset) -> Bool {
        guard let account = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return false
        }
        return (accountInfos[chainAsset.uniqueKey(accountId: account.accountId)] ?? nil)?.nonZero() == true
    }

    var fundedCount: Int {
        catalog.filter(isFunded).count
    }

    /// Writes what a TestFlight device holds before the upgrade: the first migration's marker and
    /// every stored preference, under the keys those builds used.
    func applyTestFlightState() {
        guard fixture.firstMigrationMarker == true else {
            return
        }
        userDefaults.set(true, forKey: "asset.presentation.asset_key.migrated:\(wallet.metaId)")
        for (storageKey, rawValue) in fixture.storedPreferences ?? [:] {
            userDefaults.set(rawValue, forKey: "asset.presentation.explicit.hidden:\(wallet.metaId):\(storageKey)")
        }
    }

    /// What `WalletAssetsObserverImpl.loadCompleteCatalog` runs after a complete catalog read.
    @discardableResult
    func migrate() -> [AssetKey] {
        AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: wallet,
            chainAssets: catalog,
            catalogIsComplete: true,
            userDefaults: userDefaults
        )
    }

    func preference(_ chainAsset: ChainAsset) -> AssetPreference {
        AssetVisibilityPreferenceStore.preference(
            walletId: wallet.metaId,
            assetKey: chainAsset.assetKey,
            userDefaults: userDefaults
        )
    }

    func placement(for chainAsset: ChainAsset) -> PortfolioPlacement {
        PortfolioVisibilityContext(
            wallet: wallet,
            accountInfos: accountInfos,
            networkFilter: nil,
            userDefaults: userDefaults
        ).placement(for: chainAsset)
    }

    func visibleIdentifiers() -> [String] {
        let context = PortfolioVisibilityContext(
            wallet: wallet,
            accountInfos: accountInfos,
            networkFilter: nil,
            userDefaults: userDefaults
        )
        return catalog.filter { context.placement(for: $0) == .visible }.map(\.identifier)
    }

    func explicitPreferences() -> [AssetKey: AssetPreference] {
        var result: [AssetKey: AssetPreference] = [:]
        for chainAsset in catalog where preference(chainAsset) != .auto {
            result[chainAsset.assetKey] = preference(chainAsset)
        }
        return result
    }

    struct StoredState: Equatable {
        let preferences: [AssetKey: AssetPreference]
        let legacyZeroHidden: AssetKeySet
        let hiddenInPreviousVersion: AssetKeySet
    }

    func storedState() -> StoredState {
        StoredState(
            preferences: explicitPreferences(),
            legacyZeroHidden: AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: wallet.metaId, userDefaults: userDefaults),
            hiddenInPreviousVersion: AssetVisibilityPreferenceStore.hiddenInPreviousVersion(
                walletId: wallet.metaId,
                userDefaults: userDefaults
            )
        )
    }

    /// Clears everything this scenario stored, for scenarios run against `.standard`.
    func removeStoredState() {
        for chainAsset in catalog {
            AssetVisibilityPreferenceStore.setPreference(
                .auto,
                walletId: wallet.metaId,
                assetKey: chainAsset.assetKey,
                userDefaults: userDefaults
            )
        }
        for prefix in [
            "asset.presentation.asset_key.migrated",
            "asset.presentation.asset_key.migrated.v2",
            "asset.presentation.legacy_zero_hidden",
            "asset.presentation.hidden_in_previous_version",
            "asset.presentation.hidden_funds_reviewed"
        ] {
            userDefaults.removeObject(forKey: "\(prefix):\(wallet.metaId)")
        }
    }

    static func loadFixture(_ name: String) throws -> LegacyVisibilityFixture {
        let url = try XCTUnwrap(
            Bundle(for: LegacyVisibilityMigrationV2Tests.self).url(
                forResource: name,
                withExtension: "json",
                subdirectory: "LegacyVisibility"
            ),
            name
        )
        return try JSONDecoder().decode(LegacyVisibilityFixture.self, from: Data(contentsOf: url))
    }

    /// The reviewed registry snapshot decoded with the app's own parser, plus the app-owned networks.
    /// Decoded per scenario, because fixtures add jettons to the TON network.
    static func registryChains() throws -> [ChainModel] {
        let url = try XCTUnwrap(Bundle(for: LegacyVisibilityMigrationV2Tests.self).url(
            forResource: "chains_v13_20261009", withExtension: "json", subdirectory: "Registry"
        ))
        let data = try Data(contentsOf: url)
        let chains: [ChainModel]
        do {
            chains = try JSONDecoder().decode([ChainModel].self, from: data)
        } catch {
            chains = try JSONDecoder().decode(
                [ChainModel].self,
                from: ChainSyncService.coerceChainsPayloadForCompatibility(data)
            )
        }
        return chains + UniversalWalletRegistry.appOwnedProductionChains
    }
}

private struct FixedChainCatalog: AssetDiscoveryChainCatalogProviding {
    let chains: [ChainModel]

    func fetchCatalog() async throws -> AssetDiscoveryChainCatalog {
        AssetDiscoveryChainCatalog(chains: chains, isComplete: true)
    }
}

/// Answers every scan with the scenario's balances for each requested network, as a successful
/// scan does.
private final class FundedDiscoveryStub: AssetDiscoveryService, @unchecked Sendable {
    private let scenario: LegacyVisibilityScenario
    private let lock = NSLock()
    private var scans: [Set<ChainModel.Id>] = []

    init(scenario: LegacyVisibilityScenario) {
        self.scenario = scenario
    }

    var scannedChainIds: [Set<ChainModel.Id>] {
        lock.withLock { scans }
    }

    func scan(
        wallet: MetaAccountModel,
        chains: [ChainModel],
        includeTestnets _: Bool,
        trigger: AssetDiscoveryTrigger
    ) async -> AssetDiscoveryScanResult {
        lock.withLock { scans.append(Set(chains.map(\.chainId))) }

        var accountInfosByChain: [ChainModel: [ChainAssetId: AccountInfo?]] = [:]
        for chain in chains {
            guard let account = wallet.fetch(for: chain.accountRequest()) else {
                continue
            }
            var accountInfos: [ChainAssetId: AccountInfo?] = [:]
            for chainAsset in chain.chainAssets {
                accountInfos[chainAsset.chainAssetId] = scenario.accountInfos[
                    chainAsset.uniqueKey(accountId: account.accountId)
                ] ?? nil
            }
            accountInfosByChain[chain] = accountInfos
        }
        return AssetDiscoveryScanResult(trigger: trigger, accountInfosByChain: accountInfosByChain, failedChainIds: [])
    }
}

private final class VisibilityEventRecorder: EventCenterProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var events: [AssetVisibilityPreferenceChangedEvent] = []

    var visibilityEvents: [AssetVisibilityPreferenceChangedEvent] {
        lock.withLock { events }
    }

    func notify(with event: EventProtocol) {
        guard let event = event as? AssetVisibilityPreferenceChangedEvent else {
            return
        }
        lock.withLock { events.append(event) }
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}

    func remove(observer _: EventVisitorProtocol) {}
}

/// A user store written with a Core Data model that shipped, upgraded by the release's own
/// `UserStorageMigrator` and read back through `MetaAccountMapper`.
private enum ShippedUserStore {
    static func upgradedWallet(
        from version: UserStorageVersion,
        populate: (NSManagedObject, NSManagedObjectContext, NSManagedObjectModel) throws -> Void
    ) throws -> MetaAccountModel {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyVisibilityMigrationV2Tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let appBundle = Bundle(for: UserDataStorageFacade.self)
        let identity = AccountGenerator.generateMetaAccount()
        let shippedModel = try model(for: version, in: appBundle)

        try useStore(at: storeURL, model: shippedModel) { context in
            let entity = try XCTUnwrap(shippedModel.entitiesByName["CDMetaAccount"])
            let wallet = NSManagedObject(entity: entity, insertInto: context)
            wallet.setValue(identity.metaId, forKey: "metaId")
            wallet.setValue("Upgraded wallet", forKey: "name")
            wallet.setValue(true, forKey: "isSelected")
            wallet.setValue(Int32(1), forKey: "order")
            wallet.setValue(identity.substrateAccountId?.toHex(), forKey: "substrateAccountId")
            wallet.setValue(identity.substratePublicKey, forKey: "substratePublicKey")
            wallet.setValue(Int16(identity.substrateCryptoType), forKey: "substrateCryptoType")
            wallet.setValue(identity.ethereumAddress?.toHex(), forKey: "ethereumAddress")
            wallet.setValue(identity.ethereumPublicKey, forKey: "ethereumPublicKey")
            for flag in ["canExportEthereumMnemonic", "hasBackup", "zeroBalanceAssetsHidden"]
                where entity.attributesByName[flag] != nil {
                wallet.setValue(false, forKey: flag)
            }
            if entity.attributesByName["favouriteChainIds"] != nil {
                wallet.setValue(NSArray(), forKey: "favouriteChainIds")
            }
            try populate(wallet, context, shippedModel)
            try context.save()
        }

        let migrator = UserStorageMigrator(
            targetVersion: .current,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )
        XCTAssertTrue(migrator.requiresMigration())
        try migrator.performMigration()
        XCTAssertFalse(migrator.requiresMigration())

        let currentModel = try XCTUnwrap(model(for: .current, in: appBundle).copy() as? NSManagedObjectModel)
        // Bind a private copy before a coordinator makes the model immutable.
        currentModel.entitiesByName["CDMetaAccount"]?.managedObjectClassName = NSStringFromClass(CDMetaAccount.self)
        var upgraded: MetaAccountModel?
        try useStore(at: storeURL, model: currentModel) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            upgraded = try MetaAccountMapper().transform(entity: try XCTUnwrap(context.fetch(request).first))
        }

        let wallet = try XCTUnwrap(upgraded)
        XCTAssertEqual(wallet.metaId, identity.metaId)
        XCTAssertEqual(wallet.substrateAccountId, identity.substrateAccountId)
        XCTAssertEqual(wallet.ethereumAddress, identity.ethereumAddress)
        return wallet
    }

    private static func model(for version: UserStorageVersion, in bundle: Bundle) throws -> NSManagedObjectModel {
        let url = try XCTUnwrap(
            version.modelURL(in: bundle, legacyModelDirectory: UserStorageParams.modelDirectory),
            "Missing model resource for \(version.rawValue)"
        )
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: url))
    }

    private static func useStore(
        at url: URL,
        model: NSManagedObjectModel,
        body: (NSManagedObjectContext) throws -> Void
    ) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        defer { try? coordinator.remove(store) }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var bodyError: Error?
        context.performAndWait {
            do {
                try body(context)
            } catch {
                bodyError = error
            }
        }
        if let bodyError {
            throw bodyError
        }
    }
}
