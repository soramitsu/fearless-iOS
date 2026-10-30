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

    private func makeChain(id: String, staking: RawStakingType? = .relayChain) -> ChainModel {
        let asset = AssetModel(
            id: "native", name: "Native", symbol: "NAT", precision: 12,
            isUtility: true, isNative: true, staking: staking
        )
        return ChainModel(
            rank: nil, disabled: false, chainId: String(repeating: id, count: 32),
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
