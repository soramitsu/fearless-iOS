import XCTest
import RobinHood
import SSFModels
@testable import fearless

final class WalletsManagmentInteractorTests: XCTestCase {
    func testSelect_whenInjectedEventCenterProvided_thenPublishesSelectedAccountChanged() {
        let eventCenter = WalletsManagmentEventCenterSpy()
        let output = WalletsManagmentInteractorOutputSpy()
        let interactor = makeInteractor(eventCenter: eventCenter)
        let wallet = fearless.ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount())

        output.didCompleteSelectionExpectation = expectation(description: "Selection completes")

        interactor.setup(with: output)
        interactor.select(wallet: wallet)

        wait(for: [output.didCompleteSelectionExpectation!], timeout: Constants.defaultExpectationDuration)

        let selectedEvents = eventCenter.events.compactMap { $0 as? SelectedAccountChanged }
        XCTAssertEqual(selectedEvents.map(\.account), [wallet.info])
        XCTAssertTrue(output.errors.isEmpty)
    }

    func testSetup_whenWalletNameChangedEventReceived_thenFetchesWalletsAgain() throws {
        let eventCenter = WalletsManagmentEventCenterSpy()
        let balanceAdapter = WalletBalanceSubscriptionAdapterSpy()
        let featureToggleProvider = WalletsFeatureToggleProviderStub()
        let repository = InMemoryDataProviderRepository<fearless.ManagedMetaAccountModel>()
        let operationQueue = OperationQueue()
        let wallet = fearless.ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount())
        let saveOperation = repository.saveOperation({ [wallet] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        let interactor = makeInteractor(
            walletBalanceSubscriptionAdapter: balanceAdapter,
            metaAccountRepository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            featureToggleService: featureToggleProvider
        )
        let output = WalletsManagmentInteractorOutputSpy()
        output.didReceiveWalletsExpectation = expectation(description: "Wallets fetched twice")
        output.didReceiveWalletsExpectation?.expectedFulfillmentCount = 2

        interactor.setup(with: output)
        eventCenter.notify(with: WalletNameChanged(wallet: wallet.info))

        wait(for: [output.didReceiveWalletsExpectation!], timeout: Constants.defaultExpectationDuration)

        let walletResults = try output.walletResults.map { try $0.get() }
        XCTAssertEqual(walletResults, [[wallet], [wallet]])
        XCTAssertEqual(eventCenter.observers.count, 1)
        XCTAssertEqual(balanceAdapter.walletsBalanceSubscriptionCallCount, 1)
        XCTAssertEqual(featureToggleProvider.fetchConfigOperationCallCount, 1)
    }

    private func makeInteractor(
        shouldSaveSelected: Bool = true,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol =
            WalletBalanceSubscriptionAdapterSpy(),
        metaAccountRepository: AnyDataProviderRepository<fearless.ManagedMetaAccountModel> = AnyDataProviderRepository(
            InMemoryDataProviderRepository<fearless.ManagedMetaAccountModel>()
        ),
        operationQueue: OperationQueue = OperationQueue(),
        settings: SelectedWalletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        ),
        eventCenter: EventCenterProtocol = WalletsManagmentEventCenterSpy(),
        featureToggleService: FeatureToggleProviderProtocol = WalletsFeatureToggleProviderStub()
    ) -> WalletsManagmentInteractor {
        WalletsManagmentInteractor(
            shouldSaveSelected: shouldSaveSelected,
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            metaAccountRepository: metaAccountRepository,
            operationQueue: operationQueue,
            settings: settings,
            eventCenter: eventCenter,
            featureToggleService: featureToggleService
        )
    }
}

private final class WalletsManagmentInteractorOutputSpy: WalletsManagmentInteractorOutput {
    var didCompleteSelectionExpectation: XCTestExpectation?
    var didReceiveWalletsExpectation: XCTestExpectation?

    private(set) var walletResults: [Result<[fearless.ManagedMetaAccountModel], Error>] = []
    private(set) var balanceResults: [Result<[MetaAccountId: WalletBalanceInfo], Error>] = []
    private(set) var errors: [Error] = []
    private(set) var featureToggleResults: [Result<FeatureToggleConfig, Error>?] = []

    func didReceiveWallets(_ wallets: Result<[fearless.ManagedMetaAccountModel], Error>) {
        walletResults.append(wallets)
        didReceiveWalletsExpectation?.fulfill()
    }

    func didReceiveWalletBalances(_ balances: Result<[MetaAccountId: WalletBalanceInfo], Error>) {
        balanceResults.append(balances)
    }

    func didReceive(error: Error) {
        errors.append(error)
    }

    func didCompleteSelection() {
        didCompleteSelectionExpectation?.fulfill()
    }

    func didReceiveFeatureToggleConfig(result: Result<FeatureToggleConfig, Error>?) {
        featureToggleResults.append(result)
    }
}

private final class WalletBalanceSubscriptionAdapterSpy: WalletBalanceSubscriptionAdapterProtocol {
    private(set) var walletsBalanceSubscriptionCallCount = 0

    func subscribeWalletBalance(
        wallet _: MetaAccountModel,
        listener _: WalletBalanceSubscriptionListener
    ) {}

    func subscribeWalletsBalances(listener _: WalletBalanceSubscriptionListener) {
        walletsBalanceSubscriptionCallCount += 1
    }

    func subscribeChainAssetBalance(
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset,
        listener _: WalletBalanceSubscriptionListener
    ) {}

    func subscribeChainAssetsBalance(
        chainAssets _: [ChainAsset],
        wallet _: MetaAccountModel,
        listener _: WalletBalanceSubscriptionListener
    ) {}

    func subscribeNetworkManagementBalance(
        wallet _: MetaAccountModel,
        listener _: WalletBalanceSubscriptionListener
    ) {}

    func unsubscribe(listener _: WalletBalanceSubscriptionListener) {}
}

private final class WalletsFeatureToggleProviderStub: FeatureToggleProviderProtocol {
    private(set) var fetchConfigOperationCallCount = 0

    func fetchConfigOperation() -> BaseOperation<FeatureToggleConfig> {
        fetchConfigOperationCallCount += 1
        return ClosureOperation { FeatureToggleConfig.defaultConfig }
    }
}

private final class WalletsManagmentEventCenterSpy: EventCenterProtocol {
    private(set) var events: [EventProtocol] = []
    private(set) var observers: [EventVisitorProtocol] = []
    private(set) var dispatchQueues: [DispatchQueue?] = []

    func notify(with event: EventProtocol) {
        events.append(event)
        observers.forEach { event.accept(visitor: $0) }
    }

    func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {
        observers.append(observer)
        dispatchQueues.append(queue)
    }

    func remove(observer: EventVisitorProtocol) {
        observers.removeAll { $0 === observer }
    }
}
