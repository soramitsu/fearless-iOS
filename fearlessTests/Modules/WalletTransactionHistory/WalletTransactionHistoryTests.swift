import XCTest
import UIKit
import RobinHood
import SSFModels
import FearlessFoundation
@testable import fearless

final class WalletTransactionHistoryTests: XCTestCase {
    func testSetupAndLoadNext_whenCalled_thenDelegatesToInteractor() {
        let fixture = makeFixture()
        let view = WalletTransactionHistoryViewSpy()
        fixture.interactor.loadNextResult = true

        fixture.presenter.setup(with: view)
        let result = fixture.presenter.loadNext()

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
        XCTAssertTrue(result)
    }

    func testUpdateTransactionHistory_whenChainAssetProvided_thenUpdatesInteractorChainAsset() {
        let fixture = makeFixture()
        let newChainAsset = Self.makeChainAsset(historyType: "giantsquid")

        fixture.presenter.updateTransactionHistory(for: newChainAsset)
        fixture.presenter.updateTransactionHistory(for: nil)

        XCTAssertEqual(fixture.interactor.changedChainAsset?.chain.chainId, newChainAsset.chain.chainId)
        XCTAssertTrue(fixture.interactor.didReload)
    }

    func testFilterSlider_whenKnownIndexSelected_thenAppliesSingleFilter() {
        let fixture = makeFixture()

        fixture.presenter.didChangeFiltersSliderValue(index: 1)

        let firstFilter = fixture.interactor.appliedFilters?.first?.items.first as? WalletTransactionHistoryFilter
        XCTAssertEqual(firstFilter?.type, .reward)
        XCTAssertEqual(firstFilter?.selected, true)
    }

    func testFiltersButton_whenFiltersAvailable_thenPresentsWithChainMode() {
        let fixture = makeFixture()
        let view = WalletTransactionHistoryViewSpy()
        let filters = [FilterSet(title: "Type", items: [WalletTransactionHistoryFilter(type: .transfer)])]

        fixture.presenter.setup(with: view)
        fixture.presenter.didReceive(filters: filters)
        fixture.presenter.didTapFiltersButton()

        XCTAssertEqual(fixture.wireframe.presentedFilters?.count, filters.count)
        XCTAssertEqual(fixture.wireframe.presentedMode, .multiSelection)
        XCTAssertTrue(fixture.wireframe.presentedView === view)
        XCTAssertTrue(fixture.wireframe.presentedModuleOutput === fixture.presenter)
    }

    func testDidReceivePageData_whenHistorySupported_thenBuildsAndDeliversReloadedState() {
        let fixture = makeFixture(chainAsset: Self.makeChainAsset(historyType: "giantsquid"))
        let view = WalletTransactionHistoryViewSpy()
        let transaction = Self.makeTransaction()

        fixture.presenter.setup(with: view)
        fixture.presenter.didReceive(
            pageData: AssetTransactionPageData(transactions: [transaction]),
            reload: true
        )

        XCTAssertTrue(view.didStopLoadingCalled)
        guard case let .reloaded(viewModel)? = view.receivedStates.last else {
            XCTFail("Expected reloaded transaction history state")
            return
        }

        XCTAssertEqual(viewModel.sections.count, 1)
        XCTAssertEqual(viewModel.sections.first?.items.first?.transaction, transaction)
        guard case .multiple = viewModel.filtering else {
            XCTFail("Expected multiple filter mode")
            return
        }
    }

    func testDidReceivePageData_whenHistoryUnsupportedOrFactoryFails_thenDeliversUnsupported() {
        let unsupportedFixture = makeFixture(chainAsset: Self.makeChainAsset(historyType: nil))
        let unsupportedView = WalletTransactionHistoryViewSpy()
        unsupportedFixture.presenter.setup(with: unsupportedView)

        unsupportedFixture.presenter.didReceive(
            pageData: AssetTransactionPageData(transactions: []),
            reload: true
        )

        XCTAssertTrue(unsupportedView.receivedStates.containsUnsupported)

        let failingFixture = makeFixture(chainAsset: Self.makeChainAsset(historyType: "giantsquid"))
        let failingView = WalletTransactionHistoryViewSpy()
        failingFixture.viewModelFactory.errorToThrow = TestError.expected
        failingFixture.presenter.setup(with: failingView)

        failingFixture.presenter.didReceive(
            pageData: AssetTransactionPageData(transactions: [Self.makeTransaction()]),
            reload: true
        )

        XCTAssertTrue(failingView.receivedStates.containsUnsupported)
    }

    func testDidFinishWithFilters_whenFiltersApplied_thenStartsLoadingAndAppliesFilters() {
        let fixture = makeFixture()
        let view = WalletTransactionHistoryViewSpy()
        let filters = [FilterSet(title: "Type", items: [WalletTransactionHistoryFilter(type: .other)])]

        fixture.presenter.setup(with: view)
        fixture.presenter.didFinishWithFilters(filters: filters)

        XCTAssertTrue(view.didStartLoadingCalled)
        let appliedFilter = fixture.interactor.appliedFilters?.first?.items.first as? WalletTransactionHistoryFilter
        XCTAssertEqual(appliedFilter?.type, .other)
    }

    func testHistoryService_whenOperationCompletes_thenDeliversResultOnRequestedQueue() throws {
        let pageData = AssetTransactionPageData(transactions: [Self.makeTransaction()])
        let factory = HistoryOperationFactoryStub(result: pageData)
        let operationQueue = OperationQueue()
        let service = HistoryService(operationFactory: factory, operationQueue: operationQueue)
        let chainAsset = Self.makeChainAsset(historyType: "giantsquid")
        let completionExpectation = expectation(description: "history completion")
        let completionQueue = DispatchQueue(label: "jp.co.soramitsu.fearless.tests.history.completion")
        let completionQueueKey = DispatchSpecificKey<String>()
        completionQueue.setSpecific(key: completionQueueKey, value: "history-completion")

        service.fetchTransactionHistory(
            for: "address",
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            filters: WalletTransactionHistoryFilter.defaultFilters(),
            pagination: Pagination(count: 10),
            runCompletionIn: completionQueue
        ) { result in
            XCTAssertEqual(DispatchQueue.getSpecific(key: completionQueueKey), "history-completion")

            guard case let .success(receivedPageData)? = result else {
                XCTFail("Expected successful history result")
                completionExpectation.fulfill()
                return
            }

            XCTAssertEqual(receivedPageData, pageData)
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 2)
        operationQueue.waitUntilAllOperationsAreFinished()

        XCTAssertEqual(factory.receivedAddress, "address")
        XCTAssertEqual(factory.receivedPagination?.count, 10)
        XCTAssertEqual(factory.receivedFilters?.count, WalletTransactionHistoryFilter.defaultFilters().count)
    }

    func testHistoryService_whenCancelledBeforeExecution_thenSuppressesCompletion() {
        let factory = HistoryOperationFactoryStub(result: AssetTransactionPageData(transactions: []))
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let service = HistoryService(operationFactory: factory, operationQueue: operationQueue)
        let chainAsset = Self.makeChainAsset(historyType: "giantsquid")
        let completionExpectation = expectation(description: "history completion should be suppressed")
        completionExpectation.isInverted = true

        let call = service.fetchTransactionHistory(
            for: "address",
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            filters: [],
            pagination: Pagination(count: 1),
            runCompletionIn: .main
        ) { _ in
            completionExpectation.fulfill()
        }

        call.cancel()
        operationQueue.isSuspended = false
        operationQueue.waitUntilAllOperationsAreFinished()

        wait(for: [completionExpectation], timeout: 0.2)
        XCTAssertTrue(factory.wrapper.targetOperation.isCancelled)
    }

    private func makeFixture(
        chainAsset: ChainAsset? = nil
    ) -> WalletTransactionHistoryFixture {
        let interactor = WalletTransactionHistoryInteractorInputSpy()
        let wireframe = WalletTransactionHistoryWireframeSpy()
        let viewModelFactory = WalletTransactionHistoryViewModelFactorySpy()
        let presenter = WalletTransactionHistoryPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset ?? Self.makeChainAsset(historyType: "giantsquid"),
            logger: LoggerSpy(),
            localizationManager: LocalizationManager.shared
        )

        return WalletTransactionHistoryFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )
    }

    private static func makeChainAsset(historyType: String?) -> ChainAsset {
        let asset = ChainModelGenerator.generateAssetWithId("asset-id", symbol: "dot")
        let node = ChainNodeModel(
            url: URL(string: "wss://node.example.com")!,
            name: "node",
            apikey: nil
        )
        let history = historyType.flatMap {
            ChainModel.BlockExplorer(
                type: $0,
                url: URL(string: "https://history.example.com")!
            )
        }
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: UUID().uuidString,
            parentId: nil,
            paraId: nil,
            name: "Test Chain",
            assets: [asset],
            xcm: nil,
            nodes: [node],
            addressPrefix: 0,
            icon: nil,
            externalApi: ChainModel.ExternalApiSet(history: history),
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private static func makeTransaction() -> AssetTransactionData {
        AssetTransactionData(
            transactionId: "tx-id",
            status: .commited,
            assetId: "asset-id",
            peerId: "peer-id",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: "peer-address",
            details: "details",
            amount: AmountDecimal(value: 1),
            fees: [],
            timestamp: 0,
            type: TransactionType.outgoing.rawValue,
            reason: nil,
            context: nil
        )
    }
}

private struct WalletTransactionHistoryFixture {
    let presenter: WalletTransactionHistoryPresenter
    let interactor: WalletTransactionHistoryInteractorInputSpy
    let wireframe: WalletTransactionHistoryWireframeSpy
    let viewModelFactory: WalletTransactionHistoryViewModelFactorySpy
}

private final class HistoryOperationFactoryStub: HistoryOperationFactoryProtocol {
    let wrapper: CompoundOperationWrapper<AssetTransactionPageData?>

    private(set) var receivedAddress: String?
    private(set) var receivedFilters: [WalletTransactionHistoryFilter]?
    private(set) var receivedPagination: Pagination?

    init(result: AssetTransactionPageData?) {
        wrapper = CompoundOperationWrapper.createWithResult(result)
    }

    func fetchTransactionHistoryOperation(
        asset _: AssetModel,
        chain _: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        receivedAddress = address
        receivedFilters = filters
        receivedPagination = pagination

        return wrapper
    }
}

private final class WalletTransactionHistoryViewSpy: WalletTransactionHistoryViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true
    let draggableView = UIView()
    weak var delegate: DraggableDelegate?
    let scrollPanRecognizer: UIPanGestureRecognizer? = nil

    private(set) var receivedStates: [WalletTransactionHistoryViewState] = []
    private(set) var didReloadContent = false
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func didReceive(state: WalletTransactionHistoryViewState) {
        receivedStates.append(state)
    }

    func reloadContent() {
        didReloadContent = true
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }

    func set(dragableState _: DraggableState, animated _: Bool) {}
    func set(contentInsets _: UIEdgeInsets, for _: DraggableState) {}
    func canDrag(from _: DraggableState) -> Bool { true }
    func animate(progress _: Double, from _: DraggableState, to _: DraggableState, finalFrame _: CGRect) {}
}

private final class WalletTransactionHistoryInteractorInputSpy: WalletTransactionHistoryInteractorInputProtocol {
    private(set) weak var output: WalletTransactionHistoryInteractorOutputProtocol?
    private(set) var appliedFilters: [FilterSet]?
    private(set) var changedChainAsset: ChainAsset?
    private(set) var didReload = false
    var loadNextResult = false

    func setup(with presenter: WalletTransactionHistoryInteractorOutputProtocol?) {
        output = presenter
    }

    func loadNext() -> Bool {
        loadNextResult
    }

    func applyFilters(_ filters: [FilterSet]) {
        appliedFilters = filters
    }

    func reload() {
        didReload = true
    }

    func chainAssetChanged(_ newChainAsset: ChainAsset) {
        changedChainAsset = newChainAsset
    }
}

private final class WalletTransactionHistoryWireframeSpy: WalletTransactionHistoryWireframeProtocol {
    private(set) var presentedFilters: [FilterSet]?
    private(set) var presentedMode: FiltersMode?
    private(set) weak var presentedView: ControllerBackedProtocol?
    private(set) weak var presentedModuleOutput: FiltersModuleOutput?
    private(set) var transactionDetails: AssetTransactionData?

    func presentFilters(
        with filters: [FilterSet],
        from view: ControllerBackedProtocol?,
        mode: FiltersMode,
        moduleOutput: FiltersModuleOutput?
    ) {
        presentedFilters = filters
        presentedView = view
        presentedMode = mode
        presentedModuleOutput = moduleOutput
    }

    func showTransactionDetails(
        from _: ControllerBackedProtocol?,
        transaction: AssetTransactionData,
        chain _: ChainModel,
        asset _: AssetModel,
        selectedAccount _: MetaAccountModel
    ) {
        transactionDetails = transaction
    }
}

private final class WalletTransactionHistoryViewModelFactorySpy: WalletTransactionHistoryViewModelFactoryProtocol {
    var errorToThrow: Error?

    func merge(
        newItems: [AssetTransactionData],
        into existingViewModels: inout [WalletTransactionHistorySection],
        locale _: Locale
    ) throws -> [WalletTransactionHistoryChange] {
        if let errorToThrow = errorToThrow {
            throw errorToThrow
        }

        let items = newItems.map {
            WalletTransactionHistoryCellViewModel(
                transaction: $0,
                address: "peer-address",
                icon: nil,
                transactionType: $0.type,
                amountString: "-1 DOT",
                timeString: "00:00",
                statusIcon: nil,
                status: $0.status,
                incoming: false,
                imageViewModel: nil
            )
        }

        if !items.isEmpty {
            existingViewModels.append(
                WalletTransactionHistorySection(title: "Today", items: items)
            )
        }

        return []
    }
}

private extension Array where Element == WalletTransactionHistoryViewState {
    var containsUnsupported: Bool {
        contains { state in
            if case .unsupported = state {
                return true
            }

            return false
        }
    }
}

private enum TestError: Error {
    case expected
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
