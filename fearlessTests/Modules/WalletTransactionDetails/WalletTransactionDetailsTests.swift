import XCTest
import UIKit
import FearlessFoundation
import SSFModels
@testable import fearless

final class WalletTransactionDetailsTests: XCTestCase {
    func testSetup_whenCalled_thenSetsUpInteractor() {
        let interactor = WalletTransactionDetailsInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)

        presenter.setup()

        XCTAssertEqual(interactor.setupCallCount, 1)
    }

    func testDidReceiveTransaction_whenFactoryBuildsViewModel_thenStoresAndDisplaysLoadedState() {
        let transaction = makeTransaction(type: .outgoing)
        let viewModel = makeTransferViewModel(transaction: transaction)
        let factory = WalletTransactionDetailsViewModelFactorySpy(viewModel: viewModel)
        let chain = ChainModelGenerator.generate(count: 1).first!
        let presenter = createPresenter(viewModelFactory: factory, chain: chain)
        let view = WalletTransactionDetailsViewSpy()

        presenter.view = view
        presenter.didReceiveTransaction(transaction)

        XCTAssertEqual(factory.receivedTransaction, transaction)
        XCTAssertEqual(factory.receivedChain?.chainId, chain.chainId)
        guard case let .loaded(receivedViewModel)? = view.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertTrue(receivedViewModel === viewModel)
    }

    func testDidReceiveTransaction_whenFactoryReturnsNil_thenDisplaysEmptyState() {
        let presenter = createPresenter(
            viewModelFactory: WalletTransactionDetailsViewModelFactorySpy(viewModel: nil)
        )
        let view = WalletTransactionDetailsViewSpy()

        presenter.view = view
        presenter.didReceiveTransaction(makeTransaction(type: .unused))

        guard case .empty? = view.state else {
            return XCTFail("Expected empty state")
        }
    }

    func testDidTapCloseButton_whenViewAssigned_thenClosesView() {
        let wireframe = WalletTransactionDetailsWireframeSpy()
        let presenter = createPresenter(wireframe: wireframe)
        let view = WalletTransactionDetailsViewSpy()

        presenter.view = view
        presenter.didTapCloseButton()

        XCTAssertTrue(wireframe.closedView === view)
    }

    func testDidTapSenderAndReceiver_whenTransferViewModelLoaded_thenPresentsAccountOptions() {
        let transaction = makeTransaction(type: .outgoing)
        let viewModel = makeTransferViewModel(
            transaction: transaction,
            from: "sender-address",
            to: "receiver-address"
        )
        let wireframe = WalletTransactionDetailsWireframeSpy()
        let chain = ChainModelGenerator.generate(count: 1).first!
        let presenter = createPresenter(
            wireframe: wireframe,
            viewModelFactory: WalletTransactionDetailsViewModelFactorySpy(viewModel: viewModel),
            chain: chain
        )
        let view = WalletTransactionDetailsViewSpy()

        presenter.view = view
        presenter.didReceiveTransaction(transaction)
        presenter.didTapSenderView()
        presenter.didTapReceiverOrValidatorView()

        XCTAssertEqual(view.recordingController.presentedControllers.count, 2)
        XCTAssertTrue(view.recordingController.presentedControllers.allSatisfy { $0 is UIAlertController })
    }

    func testDidTapReceiver_whenRewardViewModelLoaded_thenPresentsValidatorOptions() {
        let transaction = makeTransaction(type: .reward)
        let viewModel = RewardTransactionDetailsViewModel(
            transaction: transaction,
            transactionType: .reward,
            extrinsicHash: "hash",
            status: "Completed",
            dateString: nil,
            era: "1",
            reward: "1 DOT",
            validator: "validator-address",
            statusIcon: nil
        )
        let wireframe = WalletTransactionDetailsWireframeSpy()
        let presenter = createPresenter(
            wireframe: wireframe,
            viewModelFactory: WalletTransactionDetailsViewModelFactorySpy(viewModel: viewModel)
        )
        let view = WalletTransactionDetailsViewSpy()

        presenter.view = view
        presenter.didReceiveTransaction(transaction)
        presenter.didTapReceiverOrValidatorView()

        XCTAssertEqual(view.recordingController.presentedControllers.count, 1)
        XCTAssertTrue(view.recordingController.presentedControllers.first is UIAlertController)
    }

    func testDidTapExtrinsicView_whenViewModelLoaded_thenPresentsExtrinsicOptions() {
        let transaction = makeTransaction(type: .extrinsic)
        let viewModel = WalletTransactionDetailsViewModel(
            transaction: transaction,
            transactionType: .extrinsic,
            extrinsicHash: "0xabc",
            status: "Completed",
            dateString: nil,
            statusIcon: nil
        )
        let wireframe = WalletTransactionDetailsWireframeSpy()
        let chain = ChainModelGenerator.generate(count: 1).first!
        let presenter = createPresenter(
            wireframe: wireframe,
            viewModelFactory: WalletTransactionDetailsViewModelFactorySpy(viewModel: viewModel),
            chain: chain
        )
        let view = WalletTransactionDetailsViewSpy()

        presenter.view = view
        presenter.didReceiveTransaction(transaction)
        presenter.didTapExtrinsicView()

        XCTAssertEqual(wireframe.extrinsicHash, "0xabc")
        XCTAssertEqual(wireframe.extrinsicChain?.chainId, chain.chainId)
        XCTAssertTrue(wireframe.extrinsicView === view)
    }

    private func createPresenter(
        interactor: WalletTransactionDetailsInteractorInputProtocol = WalletTransactionDetailsInteractorInputSpy(),
        wireframe: WalletTransactionDetailsWireframeProtocol = WalletTransactionDetailsWireframeSpy(),
        viewModelFactory: WalletTransactionDetailsViewModelFactoryProtocol = WalletTransactionDetailsViewModelFactorySpy(),
        chain: ChainModel = ChainModelGenerator.generate(count: 1).first!
    ) -> WalletTransactionDetailsPresenter {
        WalletTransactionDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            chain: chain
        )
    }

    private func makeTransferViewModel(
        transaction: AssetTransactionData,
        from: String? = "from-address",
        to: String? = "to-address"
    ) -> TransferTransactionDetailsViewModel {
        TransferTransactionDetailsViewModel(
            transaction: transaction,
            transactionType: .outgoing,
            extrinsicHash: "hash",
            status: "Completed",
            dateString: nil,
            from: from,
            to: to,
            amount: "-1 DOT",
            fee: "0.01 DOT",
            total: "1.01 DOT",
            statusIcon: nil
        )
    }

    private func makeTransaction(type: TransactionType) -> AssetTransactionData {
        AssetTransactionData(
            transactionId: "tx-\(type.rawValue)",
            status: .commited,
            assetId: "asset-id",
            peerId: "peer-id",
            peerFirstName: "module",
            peerLastName: "call",
            peerName: "peer-address",
            details: "details",
            amount: AmountDecimal(value: 1),
            fees: [
                AssetTransactionFee(
                    identifier: "fee",
                    assetId: "asset-id",
                    amount: AmountDecimal(value: 0.1),
                    context: nil
                )
            ],
            timestamp: 0,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }
}

private final class WalletTransactionDetailsViewSpy: WalletTransactionDetailsViewProtocol {
    let recordingController = RecordingViewController()
    var controller: UIViewController { recordingController }
    let isSetup = false
    private(set) var state: WalletTransactionDetailsViewState?

    func didReceiveState(_ state: WalletTransactionDetailsViewState) {
        self.state = state
    }
}

private final class RecordingViewController: UIViewController {
    private(set) var presentedControllers: [UIViewController] = []

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated _: Bool,
        completion: (() -> Void)? = nil
    ) {
        presentedControllers.append(viewControllerToPresent)
        completion?()
    }
}

private final class WalletTransactionDetailsInteractorInputSpy: WalletTransactionDetailsInteractorInputProtocol {
    private(set) var setupCallCount = 0

    func setup() {
        setupCallCount += 1
    }
}

private final class WalletTransactionDetailsWireframeSpy: WalletTransactionDetailsWireframeProtocol {
    private(set) weak var closedView: ControllerBackedProtocol?
    private(set) var accountOptionViews: [ControllerBackedProtocol] = []
    private(set) var accountOptionAddresses: [String] = []
    private(set) var accountOptionChains: [ChainModel] = []
    private(set) weak var extrinsicView: ControllerBackedProtocol?
    private(set) var extrinsicHash: String?
    private(set) var extrinsicChain: ChainModel?
    private(set) weak var copyView: ControllerBackedProtocol?
    private(set) var copiedText: String?

    func close(view: ControllerBackedProtocol?) {
        closedView = view
    }

    func presentAccountOptions(
        from view: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        locale _: Locale,
        exportClosure _: (() -> Void)?
    ) {
        accountOptionViews.append(view)
        accountOptionAddresses.append(address)
        accountOptionChains.append(chain)
    }

    func presentOptions(
        with extrinsicHash: String,
        locale _: Locale,
        chain: ChainModel,
        from view: ControllerBackedProtocol?
    ) {
        self.extrinsicHash = extrinsicHash
        extrinsicChain = chain
        extrinsicView = view
    }

    func presentCopy(
        with text: String,
        locale _: Locale,
        from view: ControllerBackedProtocol?
    ) {
        copiedText = text
        copyView = view
    }
}

private final class WalletTransactionDetailsViewModelFactorySpy: WalletTransactionDetailsViewModelFactoryProtocol {
    private(set) var receivedTransaction: AssetTransactionData?
    private(set) var receivedChain: ChainModel?
    private let viewModel: WalletTransactionDetailsViewModel?

    init(viewModel: WalletTransactionDetailsViewModel? = nil) {
        self.viewModel = viewModel
    }

    func buildViewModel(
        transaction: AssetTransactionData,
        locale _: Locale,
        chain: ChainModel
    ) -> WalletTransactionDetailsViewModel? {
        receivedTransaction = transaction
        receivedChain = chain
        return viewModel
    }
}
