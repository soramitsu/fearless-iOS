import XCTest
import BigInt
import RobinHood
import SoraFoundation
import SSFUtils
import SSFModels
@testable import fearless

final class CovHSendConfirmPresenterFixture {
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let interactor: CovHSendConfirmStubInteractor
    let wireframe: CovHSendConfirmWireframeSpy
    let view = CovHSendConfirmViewSpy()
    let factory = CovHSendConfirmViewModelFactorySpy()
    let authorizer = CovHSendConfirmAuthorizer()
    let pasteboard = CovHSendPasteboard()
    let feedback = CovHSendFeedback()
    let logger = CovHSendLogger()
    let presenter: WalletSendConfirmPresenter

    init(
        chainAsset: ChainAsset,
        call: SendConfirmTransferCall? = nil,
        feeViewModel: BalanceViewModelProtocol? = nil,
        completing: Bool = true,
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount()
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        interactor = CovHSendConfirmStubInteractor(wallet: wallet)
        interactor.feeAsset = WalletSendConfirmInteractor.resolveFeePaymentChainAsset(for: chainAsset)
        wireframe = completing ? CovHSendConfirmCompletingWireframe() : CovHSendConfirmWireframeSpy()
        let transfer = Transfer(chainAsset: chainAsset, amount: 1000, receiver: "receiver-address", tip: nil, appId: nil)
        presenter = WalletSendConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            accountViewModelFactory: AccountViewModelFactory(iconGenerator: UniversalIconGenerator()),
            dataValidatingFactory: SendDataValidatingFactory(presentable: wireframe),
            walletSendConfirmViewModelFactory: factory,
            logger: logger,
            chainAsset: chainAsset,
            wallet: wallet,
            call: call ?? .transfer(transfer),
            scamInfo: nil,
            feeViewModel: feeViewModel,
            localizationManager: LocalizationManager.shared,
            submissionAuthorizer: authorizer,
            pasteboard: pasteboard,
            feedback: feedback
        )
        presenter.view = view
    }
}

final class CovHSendConfirmStubInteractor: WalletSendConfirmInteractorInputProtocol, WalletSendConfirmAttemptManaging {
    let dependencyContainer: SendDepencyContainer
    var feeAsset: ChainAsset?
    var setupCount = 0
    var submitCount = 0
    var refreshCount = 0
    var constantsCount = 0
    var retried: [String] = []
    var replacements: [String] = []
    var replaceAllowed = true
    var feeConfirmations: [BigUInt] = []
    var feeCompletions: [(Bool) -> Void] = []
    var acknowledgeResult = false
    var acknowledgements: [(hash: String, recovered: Bool)] = []
    var eqRequests: [Decimal] = []
    var isSendSelectionCurrent = true
    var cancelCount = 0

    init(wallet: MetaAccountModel) {
        dependencyContainer = SendDepencyContainer(wallet: wallet, operationManager: OperationManager())
    }

    func setup() { setupCount += 1 }
    func submitExtrinsic() { submitCount += 1 }
    func getFeePaymentChainAsset(for _: ChainAsset?) -> ChainAsset? { feeAsset }
    func fetchEquilibriumTotalBalance(chainAsset _: ChainAsset, amount: Decimal) { eqRequests.append(amount) }
    func provideConstants() { constantsCount += 1 }
    func confirmFeePresentation(fee: BigUInt, completion: @escaping (Bool) -> Void) {
        feeConfirmations.append(fee)
        feeCompletions.append(completion)
    }

    func acknowledgeSubmittedTransfer(hash: String, recoveredIdentity: TonTransferIntentIdentity?, completion: @escaping (Bool) -> Void) {
        acknowledgements.append((hash, recoveredIdentity != nil))
        completion(acknowledgeResult)
    }

    func refreshFee() { refreshCount += 1 }
    func retryUnresolvedTransfer(hash: String) { retried.append(hash) }
    func allowReplacingUnresolvedTransfer(hash: String, completion: @escaping (Bool) -> Void) {
        replacements.append(hash)
        completion(replaceAllowed)
    }

    func cancelSendAttempt() { cancelCount += 1 }
}

class CovHSendConfirmWireframeSpy: WalletSendConfirmWireframeProtocol {
    var sheets: [SheetAlertPresentableViewModel] = []
    var errors: [Error] = []
    var extrinsicFailed = 0
    var amountTooHigh = 0
    var closes = 0
    var finishes = 0
    var completed: [String] = []
    var receives: [ChainAsset] = []
    var presentsErrors = false

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheets.append(viewModel) }
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return presentsErrors
    }

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) { extrinsicFailed += 1 }
    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { amountTooHigh += 1 }
    func presentReceive(leavingSendFlowFrom _: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet _: MetaAccountModel) {
        receives.append(chainAsset)
    }

    func close(view _: ControllerBackedProtocol?) { closes += 1 }
    func finish(view _: ControllerBackedProtocol?) { finishes += 1 }
    func complete(on _: ControllerBackedProtocol?, title: String, chainAsset _: ChainAsset) { completed.append(title) }
    func presentSuccessNotification(_: String, from _: ControllerBackedProtocol?, completion _: (() -> Void)?) {}
}

final class CovHSendConfirmCompletingWireframe: CovHSendConfirmWireframeSpy, WalletSendConfirmCompletionPresenting {
    var presentedCompletions: [String] = []
    var completion: (() -> Void)?

    func completeAfterPresentation(on _: ControllerBackedProtocol?, title: String, chainAsset _: ChainAsset, completion: @escaping () -> Void) {
        presentedCompletions.append(title)
        self.completion = completion
    }
}

final class CovHSendConfirmViewSpy: UIViewController, WalletSendConfirmViewProtocol, FWTransferSealShowing {
    var states: [WalletSendConfirmViewState] = []
    var loadingFlags: [Bool] = []
    var starts = 0
    var stops = 0
    var stages: [FWSealStage] = []
    var breaks = 0

    var loadableContentView: UIView { view }
    var shouldDisableInteractionWhenLoading: Bool { false }
    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
    func didReceive(state: WalletSendConfirmViewState) { states.append(state) }
    func didReceive(isLoading: Bool) { loadingFlags.append(isLoading) }
    func didReachTransferStage(_ stage: FWSealStage) { stages.append(stage) }
    func didBreakTransfer() { breaks += 1 }
}

final class CovHSendConfirmViewModelFactorySpy: WalletSendConfirmViewModelFactoryProtocol {
    var parameters: [WalletSendConfirmViewModelFactoryParameters] = []

    func buildViewModel(parameters: WalletSendConfirmViewModelFactoryParameters) -> WalletSendConfirmViewModel {
        self.parameters.append(parameters)
        return WalletSendConfirmViewModel(
            networkName: parameters.chain.name, networkIsTestnet: false, networkIcon: nil,
            amountAttributedString: NSAttributedString(string: "1"), amountString: "1",
            senderNameString: "sender", senderAddressString: "sender-address", receiverAddressString: "receiver-address",
            priceString: "", feeAmountString: parameters.feeViewModel?.amount ?? "", feePriceString: "", tipRequired: false,
            tipAmountString: "", tipPriceString: "", showWarning: false,
            symbolViewModel: SymbolViewModel(symbolViewModel: nil, shadowColor: nil)
        )
    }
}

final class CovHSendConfirmAuthorizer: SubmissionAuthorizing {
    var granted = true
    var requests = 0

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        requests += 1
        completion(granted)
    }
}

final class CovHSendPasteboard: PasteboardStringAccessing {
    var string: String?
}

final class CovHSendFeedback: FWFeedbackPlaying {
    var plays = 0

    func play(_: FWFeedbackPattern) -> FWFeedbackOutcome {
        plays += 1
        return FWFeedbackOutcome()
    }
}

final class CovHSendLogger: LoggerProtocol {
    private let lock = NSLock()
    private var storedErrors: [String] = []

    var errors: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedErrors
    }

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message: String, file _: String, function _: String, line _: Int) {
        lock.lock()
        storedErrors.append(message)
        lock.unlock()
    }

    func customError(error: Error, file _: String, function _: String, line _: Int) {
        lock.lock()
        storedErrors.append("\(error)")
        lock.unlock()
    }
}
