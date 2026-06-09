import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
@testable import fearless

final class WalletSendConfirmTests: XCTestCase {
    func testSetup_whenCalled_thenSetsUpInteractorAndBuildsViewModel() {
        let fixture = makeFixture()
        let view = WalletSendConfirmViewSpy()
        let expectation = expectation(description: "view model delivered")
        view.onDidReceiveState = { expectation.fulfill() }
        fixture.presenter.view = view

        fixture.presenter.setup()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertTrue(view.receivedStateLoaded)
        XCTAssertEqual(fixture.viewModelFactory.lastParameters?.receiverAccountViewModel?.name, "receiver")
    }

    func testNavigationAndScamWarning_whenTapped_thenRoutesToWireframe() {
        let fixture = makeFixture(
            scamInfo: ScamInfo(name: "receiver", address: "receiver", type: .scam, subtype: "")
        )
        let view = WalletSendConfirmViewSpy()
        fixture.presenter.view = view

        fixture.presenter.didTapBackButton()
        fixture.presenter.didTapScamWarningButton()

        XCTAssertTrue(fixture.wireframe.closedView === view)
        XCTAssertNotNil(fixture.wireframe.presentedSheet)
    }

    func testConfirmXorlessTransfer_whenTapped_thenStartsLoadingAndSubmits() {
        let fixture = makeFixture(call: .xorlessTransfer(Self.makeXorlessTransfer()))
        let view = WalletSendConfirmViewSpy()
        fixture.presenter.view = view

        fixture.presenter.didTapConfirmButton()

        XCTAssertTrue(view.didStartLoadingCalled)
        XCTAssertTrue(fixture.interactor.didSubmitExtrinsic)
    }

    func testTransferResultCallbacks_whenSuccessOrFailure_thenStopsLoadingAndRoutes() {
        let fixture = makeFixture()
        let view = WalletSendConfirmViewSpy()
        fixture.presenter.view = view

        fixture.presenter.didTransfer(result: .success("0xhash"))
        fixture.presenter.didTransfer(result: .failure(TestError.expected))

        XCTAssertTrue(view.didStopLoadingCalled)
        XCTAssertEqual(fixture.wireframe.completedTitle, "0xhash")
        XCTAssertTrue(fixture.wireframe.completedView === view)
        XCTAssertTrue(fixture.wireframe.presentedError is TestError)
    }

    func testInteractorOutputs_whenBalancesAndLoadingArrive_thenUpdatesView() {
        let fixture = makeFixture()
        let view = WalletSendConfirmViewSpy()
        fixture.presenter.view = view

        fixture.presenter.didReceiveMinimumBalance(result: .success(1))
        fixture.presenter.didReceive(eqTotalBalance: 10)

        let expectation = expectation(description: "loading state delivered")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertFalse(view.loadingStates.isEmpty)
    }

    private func makeFixture(
        call: SendConfirmTransferCall? = nil,
        scamInfo: ScamInfo? = nil
    ) -> WalletSendConfirmFixture {
        let interactor = WalletSendConfirmInteractorInputSpy()
        let wireframe = WalletSendConfirmWireframeSpy()
        let viewModelFactory = WalletSendConfirmViewModelFactorySpy()
        let chainAsset = ChainModelGenerator.generateChainAsset(
            ChainModelGenerator.generateAssetWithId("asset-id", symbol: "xor"),
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 69)
        )
        let presenter = WalletSendConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            accountViewModelFactory: AccountViewModelFactorySpy(),
            dataValidatingFactory: SendDataValidatingFactory(presentable: wireframe),
            walletSendConfirmViewModelFactory: viewModelFactory,
            logger: LoggerSpy(),
            chainAsset: chainAsset,
            wallet: AccountGenerator.generateMetaAccount(with: []),
            call: call ?? .xorlessTransfer(Self.makeXorlessTransfer()),
            scamInfo: scamInfo,
            feeViewModel: BalanceViewModel(amount: "0", price: nil),
            localizationManager: LocalizationManager.shared
        )

        return WalletSendConfirmFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )
    }

    private static func makeXorlessTransfer() -> XorlessTransfer {
        XorlessTransfer(
            dexId: "0",
            assetId: SoraAssetId(wrappedValue: "0x00"),
            receiver: Data(repeating: 1, count: 32),
            amount: 1,
            desiredXorAmount: 1,
            maxAmountIn: 1,
            selectedSourceTypes: [],
            filterMode: PolkaswapCallFilterModeType(wrappedName: "disabled", wrappedValue: nil),
            additionalData: Data("receiver".utf8)
        )
    }
}

private struct WalletSendConfirmFixture {
    let presenter: WalletSendConfirmPresenter
    let interactor: WalletSendConfirmInteractorInputSpy
    let wireframe: WalletSendConfirmWireframeSpy
    let viewModelFactory: WalletSendConfirmViewModelFactorySpy
}

private final class WalletSendConfirmViewSpy: WalletSendConfirmViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true

    private(set) var states: [WalletSendConfirmViewState] = []
    private(set) var loadingStates: [Bool] = []
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false
    var onDidReceiveState: (() -> Void)?

    var receivedStateLoaded: Bool {
        states.contains { state in
            if case .loaded = state {
                return true
            }

            return false
        }
    }

    func didReceive(state: WalletSendConfirmViewState) {
        states.append(state)
        onDidReceiveState?()
    }

    func didReceive(isLoading: Bool) {
        loadingStates.append(isLoading)
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }
}

private final class WalletSendConfirmInteractorInputSpy: WalletSendConfirmInteractorInputProtocol {
    var dependencyContainer: SendDepencyContainer {
        fatalError("dependencyContainer is not used by presenter tests")
    }

    private(set) var didSetup = false
    private(set) var didSubmitExtrinsic = false
    private(set) var fetchedEquilibriumBalance: (chainAsset: ChainAsset, amount: Decimal)?
    var feePaymentChainAsset: ChainAsset?

    func setup() {
        didSetup = true
    }

    func submitExtrinsic() {
        didSubmitExtrinsic = true
    }

    func getFeePaymentChainAsset(for _: ChainAsset?) -> ChainAsset? {
        feePaymentChainAsset
    }

    func fetchEquilibriumTotalBalance(chainAsset: ChainAsset, amount: Decimal) {
        fetchedEquilibriumBalance = (chainAsset, amount)
    }

    func provideConstants() {}
}

private final class WalletSendConfirmWireframeSpy: WalletSendConfirmWireframeProtocol {
    private(set) weak var closedView: ControllerBackedProtocol?
    private(set) weak var finishedView: ControllerBackedProtocol?
    private(set) weak var completedView: ControllerBackedProtocol?
    private(set) var completedTitle: String?
    private(set) var presentedSheet: SheetAlertPresentableViewModel?
    private(set) var presentedError: Error?
    private(set) var didPresentSuccessNotification = false

    func close(view: ControllerBackedProtocol?) {
        closedView = view
    }

    func finish(view: ControllerBackedProtocol?) {
        finishedView = view
    }

    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset _: ChainAsset
    ) {
        completedView = view
        completedTitle = title
    }

    func presentSuccessNotification(
        _: String,
        from _: ControllerBackedProtocol?,
        completion closure: (() -> Void)?
    ) {
        didPresentSuccessNotification = true
        closure?()
    }

    @discardableResult
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        return true
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {
        presentedSheet = viewModel
    }

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}

private final class AccountViewModelFactorySpy: AccountViewModelFactoryProtocol {
    func buildViewModel(
        title: String,
        address: String,
        locale _: Locale
    ) -> AccountViewModel {
        AccountViewModel(title: title, name: address, icon: nil)
    }

    func buildViewModel(
        title: String,
        address: String,
        name: String?,
        locale _: Locale
    ) -> AccountViewModel {
        AccountViewModel(title: title, name: name ?? address, icon: nil)
    }
}

private final class WalletSendConfirmViewModelFactorySpy: WalletSendConfirmViewModelFactoryProtocol {
    private(set) var lastParameters: WalletSendConfirmViewModelFactoryParameters?

    func buildViewModel(
        parameters: WalletSendConfirmViewModelFactoryParameters
    ) -> WalletSendConfirmViewModel {
        lastParameters = parameters
        return WalletSendConfirmViewModel(
            amountAttributedString: NSAttributedString(string: "1 XOR"),
            amountString: "1 XOR",
            senderNameString: parameters.wallet.name,
            senderAddressString: parameters.senderAccountViewModel?.name ?? "",
            receiverAddressString: parameters.receiverAccountViewModel?.name ?? "",
            priceString: parameters.assetBalanceViewModel?.price ?? "",
            feeAmountString: parameters.feeViewModel?.amount ?? "",
            feePriceString: parameters.feeViewModel?.price ?? "",
            tipRequired: parameters.tipRequired,
            tipAmountString: parameters.tipViewModel?.amount ?? "",
            tipPriceString: parameters.tipViewModel?.price ?? "",
            showWarning: parameters.scamInfo != nil,
            symbolViewModel: SymbolViewModel(symbolViewModel: nil, shadowColor: nil)
        )
    }
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}

private enum TestError: Error {
    case expected
}
