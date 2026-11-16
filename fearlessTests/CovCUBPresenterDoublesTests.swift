import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

// Hand-written view, interactor, wireframe and strategy doubles shared by the unbond / redeem / rebond presenter tests.

/// One view double for all five staking screens; it records what each presenter hands over.
final class CovCUBViewSpy: StakingUnbondSetupViewProtocol,
    StakingUnbondConfirmViewProtocol,
    StakingRedeemConfirmationViewProtocol,
    StakingRebondConfirmationViewProtocol,
    StakingRebondSetupViewProtocol {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var loadableContentView: UIView { controller.view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    private(set) var calls: [String] = []
    private(set) var asset: LocalizableResource<AssetBalanceViewModelProtocol>?
    private(set) var fee: LocalizableResource<BalanceViewModelProtocol>?
    private(set) var footerFee: LocalizableResource<NetworkFeeFooterViewModelProtocol>?
    private(set) var input: LocalizableResource<IAmountInputViewModel>?
    private(set) var duration: LocalizableResource<TitleWithSubtitleViewModel>?
    private(set) var account: AccountViewModel?
    private(set) var title: LocalizableResource<String>?
    private(set) var hints: LocalizableResource<[TitleIconViewModel]>?
    private(set) var unbondConfirmation: StakingUnbondConfirmViewModel?
    private(set) var redeemConfirmation: StakingRedeemConfirmationViewModel?
    private(set) var rebondConfirmation: StakingRebondConfirmationViewModel?

    func applyLocalization() {}

    func didStartLoading() { calls.append("startLoading") }
    func didStopLoading() { calls.append("stopLoading") }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        calls.append("asset")
        asset = viewModel
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        calls.append(viewModel == nil ? "noFee" : "fee")
        fee = viewModel
    }

    func didReceiveFee(viewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?) {
        calls.append(viewModel == nil ? "noFee" : "fee")
        footerFee = viewModel
    }

    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>) {
        calls.append("input")
        input = viewModel
    }

    func didReceiveBonding(duration: LocalizableResource<TitleWithSubtitleViewModel>) {
        calls.append("duration")
        self.duration = duration
    }

    func didReceiveAccount(viewModel: AccountViewModel) {
        calls.append("account")
        account = viewModel
    }

    func didReceiveTitle(viewModel: LocalizableResource<String>) {
        calls.append("title")
        title = viewModel
    }

    func didReceiveHints(viewModel: LocalizableResource<[TitleIconViewModel]>) {
        calls.append("hints")
        hints = viewModel
    }

    func didReceiveConfirmation(viewModel: StakingUnbondConfirmViewModel) {
        calls.append("confirmation")
        unbondConfirmation = viewModel
    }

    func didReceiveConfirmation(viewModel: StakingRedeemConfirmationViewModel) {
        calls.append("confirmation")
        redeemConfirmation = viewModel
    }

    func didReceiveConfirmation(viewModel: StakingRebondConfirmationViewModel) {
        calls.append("confirmation")
        rebondConfirmation = viewModel
    }

    func reset() { calls.removeAll() }
}

/// One interactor double for the five presenters.
final class CovCUBInteractorSpy: StakingUnbondSetupInteractorInputProtocol,
    StakingUnbondConfirmInteractorInputProtocol,
    StakingRedeemConfirmationInteractorInputProtocol,
    StakingRebondConfirmationInteractorInputProtocol,
    StakingRebondSetupInteractorInputProtocol {
    private(set) var calls: [String] = []
    private(set) var reuseIdentifiers: [String?] = []
    private(set) var estimatedClosures: [ExtrinsicBuilderClosure?] = []
    private(set) var submittedClosures: [ExtrinsicBuilderClosure?] = []

    func setup() { calls.append("setup") }

    func estimateFee() { calls.append("estimate") }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String) {
        calls.append("estimate")
        estimatedClosures.append(builderClosure)
        reuseIdentifiers.append(reuseIdentifier)
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        calls.append("estimate")
        estimatedClosures.append(builderClosure)
        reuseIdentifiers.append(reuseIdentifier)
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        calls.append("submit")
        submittedClosures.append(builderClosure)
    }

    func reset() { calls.removeAll() }
}

/// One wireframe double for the five screens; validation alerts are recorded instead of shown.
final class CovCUBWireframeSpy: StakingUnbondSetupWireframeProtocol,
    StakingUnbondConfirmWireframeProtocol,
    StakingRedeemConfirmationWireframeProtocol,
    StakingRebondConfirmationWireframeProtocol,
    StakingRebondSetupWireframeProtocol {
    private(set) var calls: [String] = []
    private(set) var unbondFlows: [StakingUnbondConfirmFlow] = []
    private(set) var rebondAmounts: [Decimal] = []
    private(set) var rebondFlows: [StakingRebondConfirmationFlow] = []
    private(set) var hashes: [String] = []

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { calls.append("sheet") }

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        calls.append("message")
    }

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) { calls.append("info") }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        calls.append("error")
        return true
    }

    func showWeb(url _: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) { calls.append("web") }
    func dismiss(view _: ControllerBackedProtocol?) { calls.append("dismiss") }
    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("extrinsicFailed") }
    func presentUnbondingTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("unbondingTooHigh") }
    func presentRebondingTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("rebondingTooHigh") }
    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("feeNotReceived") }
    func presentFeeTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("feeTooHigh") }
    func presentNoRedeemables(from _: ControllerBackedProtocol?, locale _: Locale?) { calls.append("noRedeemables") }

    func presentMissingController(from _: ControllerBackedProtocol, address _: AccountAddress, locale _: Locale?) {
        calls.append("missingController")
    }

    var pendingStashKilledAction: (() -> Void)?

    func presentStashKilledAfterUnbond(from _: ControllerBackedProtocol, action: @escaping () -> Void, locale _: Locale?) {
        calls.append("stashKilled")
        // The real alert calls back after a tap; calling back synchronously re-enters the validation runner.
        pendingStashKilledAction = action
    }

    func close(view _: StakingUnbondSetupViewProtocol?) { calls.append("close") }
    func close(view _: StakingRebondSetupViewProtocol?) { calls.append("close") }

    func proceed(
        view _: StakingUnbondSetupViewProtocol?,
        flow: StakingUnbondConfirmFlow,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel
    ) {
        calls.append("proceed")
        unbondFlows.append(flow)
    }

    func proceed(
        view _: StakingRebondSetupViewProtocol?,
        amount: Decimal,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        flow: StakingRebondConfirmationFlow
    ) {
        calls.append("proceed")
        rebondAmounts.append(amount)
        rebondFlows.append(flow)
    }

    func complete(on _: ControllerBackedProtocol?, hash: String, chainAsset _: ChainAsset) {
        calls.append("complete")
        hashes.append(hash)
    }

    func complete(from _: StakingRedeemConfirmationViewProtocol?) { calls.append("complete") }
    func complete(from _: StakingRebondConfirmationViewProtocol?) { calls.append("complete") }
}

/// One strategy double for the interactors that only forward to their flow strategy.
final class CovCUBStrategySpy: StakingUnbondSetupStrategy,
    StakingUnbondConfirmStrategy,
    StakingRedeemConfirmationStrategy,
    StakingRebondConfirmationStrategy,
    StakingRedeemStrategy {
    private(set) var calls: [String] = []
    private(set) var reuseIdentifiers: [String?] = []

    func setup() { calls.append("setup") }

    func estimateFee(builderClosure _: ExtrinsicBuilderClosure?, reuseIdentifier: String) {
        calls.append("estimate")
        reuseIdentifiers.append(reuseIdentifier)
    }

    func estimateFee(builderClosure _: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        calls.append("estimate")
        reuseIdentifiers.append(reuseIdentifier)
    }

    func submit(builderClosure _: ExtrinsicBuilderClosure?) { calls.append("submit") }
}

enum CovCUBPresenterHost {
    /// Puts the view double's controller on screen so a presented alert can be observed.
    static func show(_ view: CovCUBViewSpy) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = view.controller
        window.makeKeyAndVisible()
        return window
    }

    static func waitForPresentation(on controller: UIViewController) {
        let deadline = Date().addingTimeInterval(2)
        while controller.presentedViewController == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    static func tearDown(_ window: UIWindow?) {
        window?.rootViewController?.dismiss(animated: false)
        window?.isHidden = true
    }
}
