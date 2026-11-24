import XCTest
import RobinHood
@testable import fearless

/// Marking a network unused in Wallet details saved the wallet through `SelectedWalletSettings.shared.performSave`,
/// which writes the wallet as the selected one and leaves the settings' value as it was. The details screen can be
/// opened for any wallet, so another wallet's details made that wallet the stored selection; for the wallet in use
/// the settings kept the old unused networks. The interactor now saves through the settings it was given.
final class WalletDetailsMarkUnusedTests: XCTestCase {
    private var facade: UserDataStorageTestFacade!
    private var settings: SelectedWalletSettings!
    private var repository: AnyDataProviderRepository<MetaAccountModel>!
    private let queue = OperationQueue()

    override func setUpWithError() throws {
        try super.setUpWithError()
        facade = UserDataStorageTestFacade()
        settings = SelectedWalletSettings(storageFacade: facade, operationQueue: queue)
        repository = AccountRepositoryFactory.createRepository(for: facade)
    }

    func testMarkingANetworkUnusedForTheWalletInUseUpdatesTheSelectedWallet() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        try select(wallet)
        let chain = CovHChainAccountFixture.chain()
        let (interactor, events, output) = makeInteractor(for: wallet)

        interactor.markUnused(chain: chain)
        CovHChainAccountFixture.spin(timeout: 10) { !events.events.isEmpty }

        XCTAssertEqual(settings.value?.metaId, wallet.metaId)
        XCTAssertEqual(settings.value?.unusedChainIds, [chain.chainId])
        XCTAssertEqual(try storedSelection(), wallet.metaId)
        XCTAssertEqual(try stored(wallet)?.unusedChainIds, [chain.chainId])
        XCTAssertEqual((events.events.first as? MetaAccountModelChangedEvent)?.account.unusedChainIds, [chain.chainId])
        XCTAssertEqual(output.flows.last?.wallet.unusedChainIds, [chain.chainId])
    }

    func testMarkingANetworkUnusedForAnotherWalletKeepsTheWalletInUse() throws {
        let inUse = AccountGenerator.generateMetaAccount()
        let other = AccountGenerator.generateMetaAccount()
        try select(inUse)
        let managed = facade.createRepository(mapper: AnyCoreDataMapper(ManagedMetaAccountMapper()))
        try execute(managed.saveOperation({ [fearless.ManagedMetaAccountModel(info: other, isSelected: false)] }, { [] }))
        let chain = CovHChainAccountFixture.chain()
        let (interactor, events, output) = makeInteractor(for: other)

        interactor.markUnused(chain: chain)
        CovHChainAccountFixture.spin(timeout: 10) { !events.events.isEmpty }

        XCTAssertEqual(settings.value?.metaId, inUse.metaId)
        XCTAssertEqual(settings.value?.unusedChainIds, inUse.unusedChainIds)
        XCTAssertEqual(try storedSelection(), inUse.metaId, "the details of another wallet do not select it")
        XCTAssertEqual(try stored(other)?.unusedChainIds, [chain.chainId])
        XCTAssertEqual((events.events.first as? MetaAccountModelChangedEvent)?.account.metaId, other.metaId)
        XCTAssertEqual(output.flows.last?.wallet.unusedChainIds, [chain.chainId])
    }

    // MARK: - Helpers

    private func makeInteractor(
        for wallet: MetaAccountModel
    ) -> (WalletDetailsInteractor, CovHChainAccountEventCenterSpy, CovHWalletDetailsOutputSpy) {
        let events = CovHChainAccountEventCenterSpy()
        let output = CovHWalletDetailsOutputSpy()
        let interactor = WalletDetailsInteractor(
            flow: .normal(wallet: wallet),
            chainsRepository: AnyDataProviderRepository(
                ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
            ),
            operationManager: OperationManager(),
            eventCenter: events,
            repository: repository,
            availableExportOptionsProvider: CovHChainAccountExportOptionsStub(),
            walletRecordsInspector: CovHWalletDetailsInspectorStub(),
            walletRecordsNoticeTracker: CovHWalletDetailsTrackerSpy(),
            selectedWalletSettings: settings,
            passwordSwitcher: UniversalWalletPasswordSwitcher(mnemonicProvider: CovHWalletDetailsMnemonicStub())
        )
        interactor.presenter = output
        return (interactor, events, output)
    }

    private func select(_ wallet: MetaAccountModel) throws {
        let saved = expectation(description: "wallet selected")
        settings.save(value: wallet, runningCompletionIn: .main) { result in
            if case let .failure(error) = result { XCTFail("selection failed: \(error)") }
            saved.fulfill()
        }
        wait(for: [saved], timeout: 10)
    }

    /// The wallet the store marks as selected, as the next launch reads it.
    private func storedSelection() throws -> MetaAccountId? {
        let relaunched = SelectedWalletSettings(storageFacade: facade, operationQueue: queue)
        let loaded = expectation(description: "selection read")
        var selected: MetaAccountId?
        relaunched.setup(runningCompletionIn: .main) { result in
            selected = (try? result.get())?.metaId
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 10)
        return selected
    }

    private func stored(_ wallet: MetaAccountModel) throws -> MetaAccountModel? {
        try execute(repository.fetchOperation(by: { wallet.metaId }, options: RepositoryFetchOptions()))
    }

    @discardableResult
    private func execute<T>(_ operation: BaseOperation<T>) throws -> T {
        queue.addOperations([operation], waitUntilFinished: true)
        return try XCTUnwrap(operation.result).get()
    }
}
