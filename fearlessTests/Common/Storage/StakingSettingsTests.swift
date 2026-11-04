import XCTest
import UIKit
import SoraFoundation
import RobinHood
import SoraKeystore
import SSFModels
@testable import fearless

final class StakingSettingsTests: XCTestCase {
    func testSetupPublishesPersistedSelectionBeforeViewFactoryReadsValue() throws {
        let chain = makeChain(id: "01")
        let fixture = try prepare(chains: [chain], selected: chain)

        fixture.settings.setup()

        XCTAssertEqual(fixture.settings.value?.chainAssetId, fixture.preferences.stakingAsset)
        XCTAssertEqual(fixture.settings.value?.chain.chainId, chain.chainId)
    }

    func testDisabledSavedChainFallsBackWithoutDeletingItsStoredRecord() throws {
        let disabled = makeChain(id: "01").replacingDisabled(true)
        let enabled = makeChain(id: "02")
        let fixture = try prepare(chains: [disabled, enabled], selected: disabled)

        fixture.settings.setup()

        XCTAssertEqual(fixture.settings.value?.chain.chainId, enabled.chainId)
        XCTAssertEqual(fixture.preferences.stakingAsset?.chainId, enabled.chainId)
        let repository = ChainRepositoryFactory(storageFacade: fixture.facade).createRepository()
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        fixture.queue.addOperations([fetch], waitUntilFinished: true)
        let retained = try fetch.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertEqual(Set(retained.map(\.chainId)), Set([disabled.chainId, enabled.chainId]))
        XCTAssertEqual(retained.first(where: { $0.chainId == disabled.chainId }), disabled)
    }

    func testDisabledOnlyCatalogHasNoActiveSelectionAndCanRecoverWhenReenabled() throws {
        let chain = makeChain(id: "01")
        let fixture = try prepare(chains: [chain.replacingDisabled(true)], selected: chain)

        fixture.settings.setup()

        XCTAssertNil(fixture.settings.value)
        XCTAssertEqual(fixture.preferences.stakingAsset?.chainId, chain.chainId)
        let repository = ChainRepositoryFactory(storageFacade: fixture.facade).createRepository()
        let save = repository.saveOperation({ [chain] }, { [] })
        fixture.queue.addOperations([save], waitUntilFinished: true)
        let _: Void = try save.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        fixture.settings.setup()

        XCTAssertEqual(fixture.settings.value?.chain.chainId, chain.chainId)
    }

    func testSavedAssetWithoutStakingFallsBackToEligibleAsset() throws {
        let noStaking = makeChain(id: "01", staking: nil)
        let eligible = makeChain(id: "02")
        let fixture = try prepare(chains: [noStaking, eligible], selected: noStaking)

        fixture.settings.setup()

        XCTAssertEqual(fixture.settings.value?.chain.chainId, eligible.chainId)
        XCTAssertEqual(fixture.preferences.stakingAsset?.chainId, eligible.chainId)
    }

    func testMissingSavedChainNeverFallsBackToDisabledChain() throws {
        let missing = makeChain(id: "01")
        let disabled = makeChain(id: "02").replacingDisabled(true)
        let fixture = try prepare(chains: [disabled], selected: missing)

        fixture.settings.setup()

        XCTAssertNil(fixture.settings.value)
        XCTAssertEqual(fixture.preferences.stakingAsset?.chainId, missing.chainId)
    }

    func testReloadAfterCatalogDisablesSelectedChainChoosesEnabledReplacement() throws {
        let first = makeChain(id: "01")
        let fallback = makeChain(id: "02")
        let fixture = try prepare(chains: [first, fallback], selected: first)
        fixture.settings.setup()
        XCTAssertEqual(fixture.settings.value?.chain.chainId, first.chainId)
        let repository = ChainRepositoryFactory(storageFacade: fixture.facade).createRepository()
        let update = repository.saveOperation({ [first.replacingDisabled(true)] }, { [] })
        fixture.queue.addOperations([update], waitUntilFinished: true)
        let _: Void = try update.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        fixture.settings.setup()

        XCTAssertEqual(fixture.settings.value?.chain.chainId, fallback.chainId)
        XCTAssertEqual(fixture.preferences.stakingAsset?.chainId, fallback.chainId)
    }

    func testLosingLastSelectedChainClearsStakingActionState() throws {
        let machine = StakingStateMachine()
        let chain = makeChain(id: "01")
        let asset = try XCTUnwrap(chain.assets.first)
        machine.state.process(chainAsset: ChainAsset(chain: chain, asset: asset))
        machine.state.process(stashItem: nil)
        XCTAssertTrue(machine.state is NoStashState)

        machine.state.process(chainAsset: nil)

        XCTAssertTrue(machine.state is InitialRelaychainStakingState)
        let state = try XCTUnwrap(machine.state as? BaseStakingState)
        XCTAssertNil(state.commonData.chainAsset)
        XCTAssertNil(state.commonData.accountInfo)
        XCTAssertNil(state.commonData.address)
    }

    func testStoredParachainStakingAssetOffersNoStaking() throws {
        let chain = makeChain(id: "01", staking: .paraChain)
        let chainAsset = ChainAsset(chain: chain, asset: try XCTUnwrap(chain.assets.first))

        XCTAssertNil(StakingType(rawStakingType: .paraChain))
        XCTAssertEqual(StakingType(rawStakingType: .relayChain), .relaychain)
        XCTAssertEqual(chainAsset.rawStakingType, .paraChain)
        XCTAssertNil(chainAsset.stakingType)

        let machine = StakingStateMachine()
        machine.state.process(chainAsset: chainAsset)

        XCTAssertTrue(machine.state is InitialRelaychainStakingState)
    }

    func testSavedParachainStakingChoiceFallsBackToSupportedStakingBeforeCleanup() throws {
        let parachainStaking = makeChain(id: "01", staking: .paraChain)
        let relayStaking = makeChain(id: "02")
        let fixture = try prepare(chains: [parachainStaking, relayStaking], selected: parachainStaking)

        fixture.settings.setup()

        XCTAssertEqual(fixture.settings.value?.chain.chainId, relayStaking.chainId)
        XCTAssertEqual(fixture.settings.value?.stakingType, .relaychain)
        XCTAssertEqual(fixture.preferences.stakingAsset?.chainId, relayStaking.chainId)
    }

    func testOnlyParachainStakingLeavesNoStakingChoice() throws {
        let parachainStaking = makeChain(id: "01", staking: .paraChain)
        let fixture = try prepare(chains: [parachainStaking], selected: parachainStaking)

        fixture.settings.setup()

        XCTAssertNil(fixture.settings.value)
    }

    func testStoredEnabledReefIsNotChosenForStakingBeforeCleanup() throws {
        let reef = makeChain(id: "01", chainId: Chain.reef.genesisHash)
        let relayStaking = makeChain(id: "02")
        let fixture = try prepare(chains: [reef, relayStaking], selected: reef)

        fixture.settings.setup()

        XCTAssertEqual(fixture.settings.value?.chain.chainId, relayStaking.chainId)
    }

    @MainActor
    func testUnavailableSelectionClearsHeaderBalanceArtworkAndNetworkWhileKeepingSelector() throws {
        let controller = StakingMainViewController(nib: R.nib.stakingMainViewController)
        controller.loadViewIfNeeded()
        let artwork = try XCTUnwrap(UIImage(systemName: "circle.fill"))
        let model = StakingMainViewModel(
            address: "retained-account", chainName: "Retained network", assetName: "RETAINED",
            assetIcon: BundleImageViewModel(image: artwork),
            balanceViewModel: LocalizableResource { _ in "123 RETAINED" }
        )
        controller.didReceive(viewModel: model)
        var pending = [try XCTUnwrap(controller.view)]
        var network: NetworkInfoView?
        while let next = pending.popLast() {
            if let candidate = next as? NetworkInfoView { network = candidate }
            pending.append(contentsOf: next.subviews)
        }
        let networkView = try XCTUnwrap(network)
        XCTAssertEqual(controller.assetSelectionView.title, "RETAINED")
        XCTAssertEqual(controller.assetSelectionView.subtitle, "123 RETAINED")
        XCTAssertEqual(controller.assetSelectionView.iconView.image, artwork)
        XCTAssertFalse(try XCTUnwrap(networkView.superview).isHidden)
        XCTAssertGreaterThan(controller.collectionView(networkView.collectionView, numberOfItemsInSection: 0), 0)

        controller.didReceive(viewModel: nil)
        controller.applyLocalization()

        XCTAssertEqual(controller.assetSelectionView.title, "")
        XCTAssertNil(controller.assetSelectionView.subtitle)
        XCTAssertNil(controller.assetSelectionView.iconView.image)
        XCTAssertTrue(try XCTUnwrap(networkView.superview).isHidden)
        XCTAssertEqual(controller.collectionView(networkView.collectionView, numberOfItemsInSection: 0), 0)
        XCTAssertTrue(controller.assetSelectionView.isEnabled)
        XCTAssertFalse(controller.assetSelectionContainerView.isHidden)
        XCTAssertTrue(controller.assetSelectionView.actions(
            forTarget: controller, forControlEvent: .touchUpInside
        )?.contains("actionAssetSelection") == true)

        controller.didReceive(viewModel: model)

        XCTAssertFalse(try XCTUnwrap(networkView.superview).isHidden)
        XCTAssertEqual(controller.assetSelectionView.subtitle, "123 RETAINED")
        XCTAssertEqual(controller.assetSelectionView.iconView.image, artwork)

        let wallet = AccountGenerator.generateMetaAccount()
        let presenter = StakingMainPresenter(
            stateViewModelFactory: EmptyStakingStateFactory(),
            networkInfoViewModelFactory: NetworkInfoViewModelFactory(),
            viewModelFacade: StakingViewModelFacade(selectedMetaAccount: wallet),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: StakingMainWireframe()),
            logger: nil, selectedMetaAccount: wallet, moduleOutput: nil
        )
        presenter.view = controller
        let chain = makeChain(id: "03")
        presenter.didReceive(newChainAsset: ChainAsset(chain: chain, asset: try XCTUnwrap(chain.assets.first)))
        // A cached balance may arrive before the address. That incomplete header must
        // stay empty, and the subsequent valid header must restore its own stories.
        presenter.didReceive(accountInfo: nil)
        XCTAssertEqual(controller.collectionView(networkView.collectionView, numberOfItemsInSection: 0), 0)
        presenter.didReceive(selectedAddress: "retained-account")
        XCTAssertEqual(controller.assetSelectionView.title, chain.name)
        XCTAssertGreaterThan(controller.collectionView(networkView.collectionView, numberOfItemsInSection: 0), 0)
        presenter.didReceive(newChainAsset: nil)
        XCTAssertEqual(controller.assetSelectionView.title, "")
        XCTAssertNil(controller.assetSelectionView.subtitle)
        XCTAssertEqual(controller.collectionView(networkView.collectionView, numberOfItemsInSection: 0), 0)
    }

    private struct EmptyStakingStateFactory: StakingStateViewModelFactoryProtocol {
        func createViewModel(from _: StakingStateProtocol) -> StakingViewState { .undefined }
    }

    private func makeChain(
        id: String,
        staking: RawStakingType? = .relayChain,
        chainId: ChainModel.Id? = nil
    ) -> ChainModel {
        let asset = AssetModel(
            id: "native", name: "Native", symbol: "NAT", precision: 12,
            isUtility: true, isNative: true, staking: staking
        )
        return ChainModel(
            rank: nil, disabled: false, chainId: chainId ?? String(repeating: id, count: 32),
            parentId: nil, paraId: nil, name: "Network \(id)", assets: [asset],
            xcm: nil, nodes: [ChainNodeModel(url: URL(string: "wss://staking-\(id).invalid")!, name: "Test", apikey: nil)],
            addressPrefix: 42, types: nil, icon: nil,
            options: nil, externalApi: nil, selectedNode: nil, customNodes: nil,
            iosMinAppVersion: nil, identityChain: nil
        )
    }

    private func prepare(chains: [ChainModel], selected: ChainModel) throws -> (
        settings: StakingAssetSettings, preferences: InMemorySettingsManager,
        facade: SubstrateStorageTestFacade, queue: OperationQueue
    ) {
        let facade = SubstrateStorageTestFacade()
        let queue = OperationQueue()
        let repository = ChainRepositoryFactory(storageFacade: facade).createRepository()
        let save = repository.saveOperation({ chains }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        let _: Void = try save.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let preferences = InMemorySettingsManager()
        preferences.stakingAsset = ChainAssetId(chainId: selected.chainId, assetId: "native")
        let settings = StakingAssetSettings(
            storageFacade: facade, settings: preferences, operationQueue: queue,
            wallet: AccountGenerator.generateMetaAccount()
        )
        return (settings, preferences, facade, queue)
    }
}

final class StakingTypeRoutingTests: XCTestCase {
    func testGlobalStakingDataSubscriptionFollowsTheStakingTypesThisBuildOffers() {
        let relayPaths = StakingRemoteSubscriptionService.globalDataStoragePaths(stakingType: .relaychain)

        XCTAssertEqual(
            relayPaths,
            [.activeEra, .currentEra, .totalIssuance, .minNominatorBond, .maxNominatorsCount, .counterForNominators]
        )
        XCTAssertEqual(StakingRemoteSubscriptionService.globalDataStoragePaths(stakingType: .sora), relayPaths)
        XCTAssertEqual(StakingRemoteSubscriptionService.globalDataStoragePaths(stakingType: .ternoa), relayPaths)
        XCTAssertTrue(
            StakingRemoteSubscriptionService.globalDataStoragePaths(
                stakingType: StakingType(rawStakingType: .paraChain)
            ).isEmpty
        )
    }

    func testRewardCalculatorFollowsTheStakingTypesThisBuildOffers() throws {
        let factory = StakingServiceFactory(
            chainRegisty: MockChainRegistryProtocol().applyDefault(for: []),
            storageFacade: SubstrateStorageTestFacade(),
            eventCenter: MockEventCenterProtocol(),
            operationManager: OperationManager()
        )
        let validatorService = EraValidatorServiceStub(info: EraStakersInfo(activeEra: 1, validators: []))

        let relay = try chainAsset(chainId: String(repeating: "01", count: 32), staking: .relayChain)
        XCTAssertTrue(
            try factory.createRewardCalculatorService(for: relay, assetPrecision: 12, validatorService: validatorService)
                is InflationRewardCalculatorService
        )

        let ternoa = try chainAsset(chainId: Chain.ternoa.genesisHash, staking: .relayChain)
        XCTAssertEqual(ternoa.stakingType, .ternoa)
        XCTAssertTrue(
            try factory.createRewardCalculatorService(for: ternoa, assetPrecision: 12, validatorService: validatorService)
                is PortionRewardCalculatorService
        )

        let sora = try chainAsset(chainId: Chain.soraMain.genesisHash, staking: .relayChain)
        XCTAssertEqual(sora.stakingType, .sora)
        XCTAssertTrue(
            try factory.createRewardCalculatorService(for: sora, assetPrecision: 18, validatorService: validatorService)
                is SoraRewardCalculatorService
        )

        let parachain = try chainAsset(chainId: Chain.moonbaseAlpha.genesisHash, staking: .paraChain)
        XCTAssertThrowsError(
            try factory.createRewardCalculatorService(for: parachain, assetPrecision: 18, validatorService: validatorService)
        ) { error in
            XCTAssertEqual(error as? StakingServiceFactoryError, .stakingUnavailable)
        }
    }

    private func chainAsset(chainId: ChainModel.Id, staking: RawStakingType) throws -> ChainAsset {
        let asset = AssetModel(
            id: "native", name: "Native", symbol: "NAT", precision: 12,
            isUtility: true, isNative: true, staking: staking
        )
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: chainId, paraId: nil, name: "Network", assets: [asset],
            xcm: nil, nodes: [], addressPrefix: 42, icon: nil, options: nil,
            iosMinAppVersion: nil, identityChain: nil
        )
        return ChainAsset(chain: chain, asset: try XCTUnwrap(chain.assets.first))
    }
}

/// Relay staking moved to Asset Hub: a saved relay choice opens the relay's Asset Hub, where the stake now lives.
final class StakingAssetHubSettingsTests: XCTestCase {
    func testSavedRelayChoiceOpensItsAssetHubAndIsRewritten() throws {
        let route = AssetHubStakingRoute.routes[0]
        let relay = makeChain(route.relayChainId, parent: nil, assetId: route.nativeAssetId, staking: nil)
        let hub = makeChain(route.stakingChainId, parent: route.relayChainId, assetId: route.nativeAssetId, staking: .assetHub)
        let saved = ChainAssetId(chainId: relay.chainId, assetId: route.nativeAssetId)
        let fixture = try prepare(chains: [relay, hub], saved: saved)

        fixture.settings.setup()

        XCTAssertEqual(fixture.settings.value?.chain.chainId, hub.chainId)
        XCTAssertEqual(fixture.settings.value?.asset.id, route.nativeAssetId)
        XCTAssertEqual(fixture.preferences.stakingAsset, ChainAssetId(chainId: hub.chainId, assetId: route.nativeAssetId))
    }

    func testFallbackPrefersAssetHubOverOtherStakingChains() throws {
        let route = AssetHubStakingRoute.routes[1]
        let other = makeChain(String(repeating: "01", count: 32), parent: nil, assetId: "native")
        let hub = makeChain(route.stakingChainId, parent: route.relayChainId, assetId: route.nativeAssetId, staking: .assetHub)
        let fixture = try prepare(chains: [other, hub], saved: nil)

        fixture.settings.setup()

        XCTAssertEqual(fixture.settings.value?.chain.chainId, hub.chainId)
        XCTAssertEqual(fixture.preferences.stakingAsset?.chainId, hub.chainId)
    }

    func testMigratedRelayCannotBeSavedAsStakingChoice() throws {
        let route = AssetHubStakingRoute.routes[0]
        let relay = makeChain(route.relayChainId, parent: nil, assetId: route.nativeAssetId)
        let fixture = try prepare(chains: [relay], saved: nil)
        let asset = try XCTUnwrap(relay.assets.first)
        let refused = XCTestExpectation(description: "relay save refused")

        fixture.settings.save(value: ChainAsset(chain: relay, asset: asset), runningCompletionIn: nil) { result in
            if case .failure = result { refused.fulfill() }
        }

        wait(for: [refused], timeout: 30)
        XCTAssertNil(fixture.preferences.stakingAsset)
    }

    private func makeChain(
        _ chainId: String,
        parent: String?,
        assetId: String,
        staking: RawStakingType? = .relayChain
    ) -> ChainModel {
        let asset = AssetModel(
            id: assetId, name: "Native", symbol: "NAT", precision: 10,
            isUtility: true, isNative: true, staking: staking, type: .normal
        )
        return ChainModel(
            rank: nil, disabled: false, chainId: chainId,
            parentId: parent, paraId: parent == nil ? nil : "1000", name: "Network", assets: [asset],
            xcm: nil, nodes: [ChainNodeModel(url: URL(string: "wss://staking-\(chainId.prefix(16)).invalid")!, name: "Test", apikey: nil)],
            addressPrefix: 0, icon: nil, iosMinAppVersion: nil, identityChain: nil
        )
    }

    private func prepare(chains: [ChainModel], saved: ChainAssetId?) throws -> (
        settings: StakingAssetSettings, preferences: InMemorySettingsManager
    ) {
        let facade = SubstrateStorageTestFacade()
        let queue = OperationQueue()
        let repository = ChainRepositoryFactory(storageFacade: facade).createRepository()
        let save = repository.saveOperation({ chains }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        let _: Void = try save.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let preferences = InMemorySettingsManager()
        preferences.stakingAsset = saved
        let settings = StakingAssetSettings(
            storageFacade: facade, settings: preferences, operationQueue: queue,
            wallet: AccountGenerator.generateMetaAccount()
        )
        return (settings, preferences)
    }
}

/// What staking screens may offer or save while stored chains are not cleaned up yet after an upgrade.
final class StakingChoiceTests: XCTestCase {
    func testPickerOffersOnlyStakingThisBuildOffersBeforeStoredChainsAreCleanedUp() {
        let route = AssetHubStakingRoute.routes[0]
        let migratedRelay = makeChain(route.relayChainId, assetId: route.nativeAssetId, options: [.poolStaking])
        let hub = makeChain(
            route.stakingChainId,
            parent: route.relayChainId,
            assetId: route.nativeAssetId,
            staking: .assetHub,
            options: [.poolStaking]
        )
        let reef = makeChain(Chain.reef.genesisHash)
        let moonbaseAlpha = makeChain(Chain.moonbaseAlpha.genesisHash, staking: .paraChain)
        let ternoa = makeChain(Chain.ternoa.genesisHash, options: [.poolStaking])
        let presenter = StakingAssetSelectionPresenter(
            interactor: MockChainSelectionInteractorInputProtocol(),
            wireframe: MockAssetSelectionWireframeProtocol(),
            assetFilter: { $0.offersStaking },
            type: .normal(chainAsset: nil),
            selectedMetaAccount: AccountGenerator.generateMetaAccount(),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            localizationManager: LocalizationManager.shared
        )

        presenter.didReceiveChains(result: .success([migratedRelay, hub, reef, moonbaseAlpha, ternoa]))

        let entries = (0 ..< presenter.numberOfItems).compactMap {
            (presenter.item(at: $0) as? AssetSelectionTableViewCellModel)?.stakingType
        }
        let direct = entries.compactMap { entry -> ChainModel.Id? in
            guard case let .normal(chainAsset) = entry else { return nil }
            return chainAsset?.chain.chainId
        }
        let pools = entries.compactMap { entry -> ChainModel.Id? in
            guard case let .pool(chainAsset) = entry else { return nil }
            return chainAsset?.chain.chainId
        }
        XCTAssertEqual(direct, [hub.chainId, ternoa.chainId])
        XCTAssertEqual(pools, [ternoa.chainId], "no pools on a migrated relay or an Asset Hub")
    }

    func testSavingAChoiceThisBuildDoesNotOfferIsRefused() throws {
        let preferences = InMemorySettingsManager()
        let settings = StakingAssetSettings(
            storageFacade: SubstrateStorageTestFacade(),
            settings: preferences,
            operationQueue: OperationQueue(),
            wallet: AccountGenerator.generateMetaAccount()
        )
        let refused = [
            makeChain(Chain.reef.genesisHash),
            makeChain(Chain.moonbaseAlpha.genesisHash, staking: .paraChain),
            makeChain(Chain.ternoa.genesisHash).replacingDisabled(true)
        ]

        for chain in refused {
            XCTAssertFalse(try save(chain, in: settings), chain.chainId)
        }
        XCTAssertNil(preferences.stakingAsset)

        let ternoa = makeChain(Chain.ternoa.genesisHash)
        XCTAssertTrue(try save(ternoa, in: settings))
        XCTAssertEqual(preferences.stakingAsset?.chainId, ternoa.chainId)
    }

    private func save(_ chain: ChainModel, in settings: StakingAssetSettings) throws -> Bool {
        let asset = try XCTUnwrap(chain.assets.first)
        var succeeded = false
        let finished = XCTestExpectation(description: "save finished")
        settings.save(value: ChainAsset(chain: chain, asset: asset), runningCompletionIn: nil) { result in
            if case .success = result {
                succeeded = true
            }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 30)
        return succeeded
    }

    private func makeChain(
        _ chainId: ChainModel.Id,
        parent: ChainModel.Id? = nil,
        assetId: AssetModel.Id = "native",
        staking: RawStakingType = .relayChain,
        options: [ChainOptions]? = nil
    ) -> ChainModel {
        let asset = AssetModel(
            id: assetId, name: "Native", symbol: "NAT", precision: 10,
            isUtility: true, isNative: true, staking: staking, type: .normal
        )
        return ChainModel(
            rank: nil, disabled: false, chainId: chainId, parentId: parent, paraId: parent == nil ? nil : "1000",
            name: "Network", assets: [asset], xcm: nil,
            nodes: [ChainNodeModel(url: URL(string: "wss://choice-\(chainId.prefix(16)).invalid")!, name: "Test", apikey: nil)],
            addressPrefix: 0, icon: nil, options: options, iosMinAppVersion: nil, identityChain: nil
        )
    }
}
