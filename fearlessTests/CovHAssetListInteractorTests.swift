import XCTest
import RobinHood
import SoraKeystore
import SSFModels
@testable import fearless

final class CovHAssetListEventSpy: EventVisitorProtocol {
    private(set) var visibilityEvents: [AssetVisibilityPreferenceChangedEvent] = []
    private(set) var changedAccounts: [MetaAccountModel] = []

    func processAssetVisibilityPreferenceChanged(event: AssetVisibilityPreferenceChangedEvent) {
        visibilityEvents.append(event)
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        changedAccounts.append(event.account)
    }
}

final class CovHAssetListInteractorTests: XCTestCase {
    private var harness: CovHAssetListInteractorHarness!

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    func testSetupReportsTheChainsThatMissAnAccount() throws {
        let chain = CovHAssetListFixture.chain(name: "Missing account network")
        harness = CovHAssetListInteractorHarness(missingChains: [chain])
        harness.interactor.setup(with: harness.output)

        let issues = try XCTUnwrap(harness.output.issues.last)
        XCTAssertEqual(issues.count, 1)
        guard case let .missingAccount(chains) = try XCTUnwrap(issues.first) else {
            return XCTFail("Expected a missing account issue")
        }
        XCTAssertEqual(chains.map(\.chainId), [chain.chainId])

        harness.interactor.handleChainsIssues([.network(chains: [chain])])
        guard case let .network(networkChains) = try XCTUnwrap(harness.output.issues.last?.first) else {
            return XCTFail("Expected a network issue")
        }
        XCTAssertEqual(networkChains.map(\.chainId), [chain.chainId])
    }

    func testCatalogLoadDeliversTheListAndItsBalances() throws {
        harness = CovHAssetListInteractorHarness()
        harness.interactor.setup(with: harness.output)
        harness.loadEmptyCatalog()

        let first = try XCTUnwrap(harness.output.chainAssetResults.first)
        XCTAssertEqual(try first.get().count, 0)
        XCTAssertEqual(harness.output.accountInfoDeliveries, 1)
        XCTAssertEqual(
            Array(harness.output.events.filter { $0 != "issues" && $0 != "chainSettings" }.prefix(2)),
            ["chainAssets", "accountInfos"]
        )
    }

    func testReloadBeforeTheCatalogOnlyAnnouncesTheRefresh() {
        harness = CovHAssetListInteractorHarness()
        harness.interactor.setup(with: harness.output)
        var announcements = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .universalWalletPortfolioRefreshed,
            object: nil,
            queue: nil
        ) { _ in announcements += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        harness.interactor.reload()

        XCTAssertEqual(announcements, 1)
        XCTAssertTrue(harness.output.chainAssetResults.isEmpty)
        XCTAssertEqual(harness.prices.updates, 0)
    }

    func testReloadRepeatsTheListAndThrottlesRemoteRefresh() {
        harness = CovHAssetListInteractorHarness()
        harness.interactor.setup(with: harness.output)
        harness.loadEmptyCatalog()
        let listsBefore = harness.output.chainAssetResults.count
        let balancesBefore = harness.output.accountInfoDeliveries

        harness.interactor.reload()
        XCTAssertEqual(harness.output.chainAssetResults.count, listsBefore + 1)
        XCTAssertEqual(harness.output.accountInfoDeliveries, balancesBefore + 1)
        XCTAssertEqual(harness.prices.updates, 1)
        CovHAssetListFixture.spin(timeout: 10) { harness.output.accountInfoDeliveries >= balancesBefore + 2 }
        XCTAssertGreaterThanOrEqual(harness.output.accountInfoDeliveries, balancesBefore + 2)

        harness.interactor.reload()
        XCTAssertEqual(harness.prices.updates, 1, "A second refresh within the timer window does not ask for prices again")
        XCTAssertEqual(harness.output.chainAssetResults.count, listsBefore + 2)
    }

    func testManageAssetAnimationFlagIsSwitchedOffOnce() {
        harness = CovHAssetListInteractorHarness()
        XCTAssertTrue(harness.interactor.shouldRunManageAssetAnimate)

        harness.interactor.shouldRunManageAssetAnimate = false
        XCTAssertFalse(harness.interactor.shouldRunManageAssetAnimate)

        harness.interactor.shouldRunManageAssetAnimate = true
        XCTAssertFalse(harness.interactor.shouldRunManageAssetAnimate, "Once played, the animation never comes back")
    }

    func testAvailableChainAssetsAreTheRelatedOnesOrNothing() {
        harness = CovHAssetListInteractorHarness()
        let asset = CovHAssetListFixture.chainAsset(id: "origin")
        let other = CovHAssetListFixture.chainAsset(id: "other", symbol: "OTH")
        harness.fetching.result = .success([asset, other])

        var related: [ChainAsset]?
        harness.interactor.getAvailableChainAssets(chainAsset: asset) { related = $0 }
        CovHAssetListFixture.spin { related != nil }
        XCTAssertEqual(related?.map(\.assetKey), [asset.assetKey])
        XCTAssertEqual(harness.fetching.requests.count, 1)

        harness.fetching.result = .failure(NSError(domain: "cov-h", code: 5))
        var failed: [ChainAsset]?
        harness.interactor.getAvailableChainAssets(chainAsset: asset) { failed = $0 }
        CovHAssetListFixture.spin { failed != nil }
        XCTAssertEqual(failed?.count, 0)
    }

    func testHideAndShowUpdateTheListAndNotifyTheWalletBalance() throws {
        harness = CovHAssetListInteractorHarness()
        let events = CovHAssetListEventSpy()
        harness.eventCenter.add(observer: events, dispatchIn: .main)
        harness.interactor.setup(with: harness.output)
        let asset = CovHAssetListFixture.chainAsset(id: "hidden-\(UUID().uuidString)")
        defer {
            AssetVisibilityPreferenceStore.setPreference(.auto, walletId: harness.wallet.metaId, assetKey: asset.assetKey)
        }

        harness.interactor.hideChainAsset(asset)
        XCTAssertEqual(harness.output.viewModelUpdates, 1)
        CovHAssetListFixture.spin { events.visibilityEvents.count == 1 }
        XCTAssertEqual(events.visibilityEvents.first?.preference, .hidden)
        XCTAssertEqual(events.visibilityEvents.first?.assetKey, asset.assetKey)
        CovHAssetListFixture.spin { harness.output.viewModelUpdates == 2 }
        XCTAssertEqual(harness.output.viewModelUpdates, 2, "The interactor's own wallet event refreshes the list once more")

        harness.interactor.showChainAsset(asset)
        CovHAssetListFixture.spin { events.visibilityEvents.count == 2 }
        XCTAssertEqual(events.visibilityEvents.last?.preference, .shown)
        XCTAssertEqual(
            AssetVisibilityPreferenceStore.preference(walletId: harness.wallet.metaId, assetKey: asset.assetKey),
            .shown
        )
    }

    func testVisibilityEventsOfAnotherWalletAreIgnored() {
        harness = CovHAssetListInteractorHarness()
        harness.interactor.setup(with: harness.output)
        let asset = CovHAssetListFixture.chainAsset()

        harness.interactor.processAssetVisibilityPreferenceChanged(
            event: AssetVisibilityPreferenceChangedEvent(walletId: "another", assetKey: asset.assetKey, preference: .hidden)
        )
        XCTAssertEqual(harness.output.viewModelUpdates, 0)

        harness.interactor.processAssetVisibilityPreferenceChanged(
            event: AssetVisibilityPreferenceChangedEvent(walletId: harness.wallet.metaId, assetKey: asset.assetKey, preference: .hidden)
        )
        XCTAssertEqual(harness.output.viewModelUpdates, 1)
    }

    func testRetryConnectionAsksTheRegistry() {
        harness = CovHAssetListInteractorHarness()
        harness.interactor.retryConnection(for: "cov-h-chain")
        XCTAssertEqual(harness.registry.retries, ["cov-h-chain"])
    }

    func testWalletEditsReactToWhatChanged() {
        harness = CovHAssetListInteractorHarness()
        harness.interactor.setup(with: harness.output)
        harness.loadEmptyCatalog()
        let lists = harness.output.chainAssetResults.count

        harness.interactor.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: AccountGenerator.generateMetaAccount()))
        XCTAssertTrue(harness.output.wallets.isEmpty, "Another wallet's edit is ignored")

        let renamed = harness.wallet.replacingName("Renamed")
        harness.interactor.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: renamed))
        XCTAssertEqual(harness.output.wallets.map(\.name), ["Renamed"])
        XCTAssertEqual(harness.output.viewModelUpdates, 0)

        let unused = renamed.replacingUnusedChainIds(["cov-h-unused"])
        harness.interactor.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: unused))
        XCTAssertEqual(harness.output.wallets.count, 2)
        XCTAssertEqual(harness.output.viewModelUpdates, 1)

        let moved = unused.replacingChainAccounts([AccountGenerator.generateChainAccount()])
        harness.interactor.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: moved))
        XCTAssertEqual(harness.output.changedWallets.map(\.metaId), [harness.wallet.metaId])
        CovHAssetListFixture.spin(timeout: 10) { harness.output.chainAssetResults.count > lists }
        XCTAssertEqual(harness.output.chainAssetResults.count, lists + 1, "New accounts reload the catalog")
    }

    func testSelectingAnotherWalletClearsBalancesAndReloads() {
        harness = CovHAssetListInteractorHarness()
        harness.interactor.setup(with: harness.output)
        harness.loadEmptyCatalog()
        let lists = harness.output.chainAssetResults.count
        let balances = harness.output.accountInfoDeliveries
        let other = AccountGenerator.generateMetaAccount()

        harness.interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: other))

        XCTAssertEqual(harness.output.changedWallets.map(\.metaId), [other.metaId])
        XCTAssertEqual(harness.output.accountInfoDeliveries, balances + 1)
        CovHAssetListFixture.spin(timeout: 10) { harness.output.chainAssetResults.count > lists }
        XCTAssertEqual(harness.output.chainAssetResults.count, lists + 1)
    }

    func testCatalogEventsReloadTheList() {
        harness = CovHAssetListInteractorHarness()
        harness.interactor.setup(with: harness.output)
        harness.loadEmptyCatalog()
        var lists = harness.output.chainAssetResults.count

        harness.interactor.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: []))
        CovHAssetListFixture.spin(timeout: 10) { harness.output.chainAssetResults.count > lists }
        XCTAssertEqual(harness.output.chainAssetResults.count, lists + 1)
        lists = harness.output.chainAssetResults.count

        harness.interactor.processChainSyncDidComplete(event: ChainSyncDidComplete(newOrUpdatedChains: [], removedChains: []))
        CovHAssetListFixture.spin(timeout: 10) { harness.output.chainAssetResults.count > lists }
        XCTAssertEqual(harness.output.chainAssetResults.count, lists + 1)
        lists = harness.output.chainAssetResults.count

        harness.interactor.processPricesUpdated()
        CovHAssetListFixture.spin(timeout: 10) { harness.output.chainAssetResults.count > lists }
        XCTAssertEqual(harness.output.chainAssetResults.count, lists + 1)

        let events = harness.output.events.count
        harness.interactor.processRemoteSubscriptionWasUpdated(
            event: WalletRemoteSubscriptionWasUpdatedEvent(chainAsset: CovHAssetListFixture.chainAsset())
        )
        XCTAssertEqual(harness.output.events.count, events, "A new remote subscription only subscribes; the list stays")
    }

    func testStoredSeedAdoptionFailureIsReported() throws {
        let adopter = CovHAssetListAdopterStub()
        adopter.error = UniversalWalletStoredSeedAdopter.AdoptionError.storedWalletSeedUnavailable
        harness = CovHAssetListInteractorHarness(adopter: adopter)
        harness.interactor.setup(with: harness.output)

        harness.interactor.adoptStoredWalletSeed()
        CovHAssetListFixture.spin { !harness.output.adoptions.isEmpty }

        let result = try XCTUnwrap(harness.output.adoptions.first)
        guard case let .failure(error) = result else { return XCTFail("Expected a failure") }
        XCTAssertEqual(error as? UniversalWalletStoredSeedAdopter.AdoptionError, .storedWalletSeedUnavailable)
        XCTAssertEqual(adopter.requests.map(\.metaId), [harness.wallet.metaId])
    }

    func testStoredSeedAdoptionWithoutASelectedWalletFails() throws {
        let adopter = CovHAssetListAdopterStub()
        harness = CovHAssetListInteractorHarness(adopter: adopter)
        harness.interactor.setup(with: harness.output)

        harness.interactor.adoptStoredWalletSeed()
        CovHAssetListFixture.spin { !harness.output.adoptions.isEmpty }

        let result = try XCTUnwrap(harness.output.adoptions.first)
        guard case .failure = result else { return XCTFail("Expected a failure while no wallet is selected") }
        XCTAssertEqual(adopter.requests.count, 1)
    }

    func testStoredSeedAdoptionSavesTheAccountsAndReloads() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            Data(repeating: 0x2B, count: UniversalWalletSeedBridge.walletSeedLength),
            with: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        )
        try keychain.saveKey(
            Data(UniversalWalletSeedBridge.contract.utf8),
            with: fearless.KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
        )
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        var saved = false
        settings.save(value: wallet, runningCompletionIn: .main) { _ in saved = true }
        CovHAssetListFixture.spin { saved }
        XCTAssertTrue(saved)

        harness = CovHAssetListInteractorHarness(
            wallet: wallet,
            adopter: UniversalWalletStoredSeedAdopter(keystore: keychain),
            walletSettings: settings
        )
        let events = CovHAssetListEventSpy()
        harness.eventCenter.add(observer: events, dispatchIn: .main)
        harness.interactor.setup(with: harness.output)
        harness.loadEmptyCatalog()
        let lists = harness.output.chainAssetResults.count

        harness.interactor.adoptStoredWalletSeed()
        CovHAssetListFixture.spin(timeout: 10) { !harness.output.adoptions.isEmpty }

        let adopted = try XCTUnwrap(try? harness.output.adoptions.first?.get())
        XCTAssertTrue(
            UniversalWalletChainAccountSupport.hasValidDedicatedAccount(in: adopted, for: UniversalWalletRegistry.bitcoinMainnet.chainId)
        )
        XCTAssertEqual(settings.value?.chainAccounts, adopted.chainAccounts)
        CovHAssetListFixture.spin(timeout: 10) { !events.changedAccounts.isEmpty && harness.output.chainAssetResults.count > lists }
        XCTAssertEqual(events.changedAccounts.first?.metaId, wallet.metaId)
        XCTAssertGreaterThan(harness.output.chainAssetResults.count, lists)
    }
}
