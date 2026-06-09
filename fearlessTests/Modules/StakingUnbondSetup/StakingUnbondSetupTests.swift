import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingUnbondSetupTests: XCTestCase {
    func testSetup_whenCalled_thenBindsStateProvidesViewModelsAndSetsUpInteractor() {
        let sut = makeSut()

        sut.presenter.setup()

        XCTAssertTrue(sut.viewModelState.stateListener === sut.presenter)
        XCTAssertEqual(sut.view.inputCallCount, 1)
        XCTAssertEqual(sut.view.feeCallCount, 1)
        XCTAssertEqual(sut.view.assetCallCount, 1)
        XCTAssertEqual(sut.view.bondingCallCount, 1)
        XCTAssertEqual(sut.view.titleCallCount, 1)
        XCTAssertEqual(sut.view.accountCallCount, 1)
        XCTAssertEqual(sut.view.collatorCallCount, 1)
        XCTAssertEqual(sut.view.hintsCallCount, 1)
        XCTAssertEqual(sut.interactor.setupCallCount, 1)
    }

    func testAmountActions_whenCalled_thenDelegateToState() {
        let sut = makeSut()

        sut.presenter.selectAmountPercentage(0.75)
        sut.presenter.updateAmount(4.5)

        XCTAssertEqual(sut.viewModelState.selectedPercentages, [0.75])
        XCTAssertEqual(sut.viewModelState.updatedAmounts, [4.5])
    }

    func testProceed_whenFlowAndValidatorsPass_thenRoutesConfirmation() {
        let sut = makeSut()
        sut.viewModelState.confirmationFlow = .relaychain(amount: 4.5)

        sut.presenter.proceed()

        XCTAssertEqual(sut.wireframe.proceedCallCount, 1)
        XCTAssertEqual(sut.wireframe.lastProceedChainAsset?.chain.chainId, sut.chainAsset.chain.chainId)
        XCTAssertEqual(sut.wireframe.lastProceedWallet?.metaId, sut.wallet.metaId)

        guard case let .relaychain(amount)? = sut.wireframe.lastProceedFlow else {
            return XCTFail("Expected relaychain confirmation flow")
        }

        XCTAssertEqual(amount, 4.5)
    }

    func testProceed_whenFlowMissing_thenDoesNotRouteConfirmation() {
        let sut = makeSut()
        sut.viewModelState.confirmationFlow = nil

        sut.presenter.proceed()

        XCTAssertEqual(sut.wireframe.proceedCallCount, 0)
        XCTAssertEqual(sut.viewModelState.validatorsCallCount, 0)
    }

    func testUpdateFeeIfNeeded_whenStateRequestsFee_thenEstimatesFee() {
        let sut = makeSut()
        sut.presenter.setup()

        sut.viewModelState.stateListener?.updateFeeIfNeeded()

        XCTAssertEqual(sut.interactor.estimateFeeCallCount, 1)
        XCTAssertEqual(sut.interactor.lastReuseIdentifier, sut.viewModelState.reuseIdentifier)
    }

    func testCloseAndBack_whenCalled_thenRouteThroughWireframe() {
        let sut = makeSut()

        sut.presenter.close()
        sut.presenter.didTapBackButton()

        XCTAssertEqual(sut.wireframe.closeCallCount, 1)
        XCTAssertEqual(sut.wireframe.dismissCallCount, 1)
    }

    private func makeSut() -> StakingUnbondSetupSut {
        let chainAsset = ChainModelGenerator.generateChainAsset(
            ChainModelGenerator.generateAssetWithId("asset-id", symbol: "dot", assetPresicion: 12),
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0, assetPresicion: 12)
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let view = StakingUnbondSetupViewSpy()
        let interactor = StakingUnbondSetupInteractorSpy()
        let wireframe = StakingUnbondSetupWireframeSpy()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        dataValidatingFactory.view = view
        let viewModelState = StakingUnbondSetupViewModelStateSpy()
        let viewModelFactory = StakingUnbondSetupViewModelFactorySpy()

        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            dataValidatingFactory: dataValidatingFactory,
            viewModelFactory: viewModelFactory,
            viewModelState: viewModelState,
            chainAsset: chainAsset,
            wallet: wallet
        )
        presenter.view = view

        return StakingUnbondSetupSut(
            presenter: presenter,
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            viewModelState: viewModelState,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }
}

private struct StakingUnbondSetupSut {
    let presenter: StakingUnbondSetupPresenter
    let view: StakingUnbondSetupViewSpy
    let interactor: StakingUnbondSetupInteractorSpy
    let wireframe: StakingUnbondSetupWireframeSpy
    let viewModelState: StakingUnbondSetupViewModelStateSpy
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
}

private final class StakingUnbondSetupViewSpy: StakingUnbondSetupViewProtocol {
    var localizationManager: LocalizationManagerProtocol?
    let controller = UIViewController()

    private(set) var assetCallCount = 0
    private(set) var feeCallCount = 0
    private(set) var inputCallCount = 0
    private(set) var bondingCallCount = 0
    private(set) var accountCallCount = 0
    private(set) var collatorCallCount = 0
    private(set) var titleCallCount = 0
    private(set) var hintsCallCount = 0

    var isSetup: Bool { true }

    func applyLocalization() {}

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetCallCount += 1
    }

    func didReceiveFee(viewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?) {
        feeCallCount += 1
    }

    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>) {
        inputCallCount += 1
    }

    func didReceiveBonding(duration: LocalizableResource<TitleWithSubtitleViewModel>) {
        bondingCallCount += 1
    }

    func didReceiveAccount(viewModel: AccountViewModel) {
        accountCallCount += 1
    }

    func didReceiveCollator(viewModel: AccountViewModel) {
        collatorCallCount += 1
    }

    func didReceiveTitle(viewModel: LocalizableResource<String>) {
        titleCallCount += 1
    }

    func didReceiveHints(viewModel: LocalizableResource<[TitleIconViewModel]>) {
        hintsCallCount += 1
    }
}

private final class StakingUnbondSetupInteractorSpy: StakingUnbondSetupInteractorInputProtocol {
    private(set) var setupCallCount = 0
    private(set) var estimateFeeCallCount = 0
    private(set) var lastReuseIdentifier: String?
    private(set) var lastBuilderClosure: ExtrinsicBuilderClosure?

    func setup() {
        setupCallCount += 1
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String) {
        estimateFeeCallCount += 1
        lastBuilderClosure = builderClosure
        lastReuseIdentifier = reuseIdentifier
    }
}

private final class StakingUnbondSetupWireframeSpy: StakingUnbondSetupWireframeProtocol {
    private(set) var closeCallCount = 0
    private(set) var dismissCallCount = 0
    private(set) var proceedCallCount = 0
    private(set) var presentedMessages: [String] = []
    private(set) var shownWebUrls: [URL] = []
    private(set) var lastProceedFlow: StakingUnbondConfirmFlow?
    private(set) var lastProceedChainAsset: ChainAsset?
    private(set) var lastProceedWallet: MetaAccountModel?

    func close(view: StakingUnbondSetupViewProtocol?) {
        closeCallCount += 1
    }

    func proceed(
        view: StakingUnbondSetupViewProtocol?,
        flow: StakingUnbondConfirmFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        proceedCallCount += 1
        lastProceedFlow = flow
        lastProceedChainAsset = chainAsset
        lastProceedWallet = wallet
    }

    func dismiss(view: ControllerBackedProtocol?) {
        dismissCallCount += 1
    }

    func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle) {
        shownWebUrls.append(url)
    }

    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        presentedMessages.append(String(describing: error))
        return true
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    ) {
        presentedMessages.append(viewModel.title)
    }

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from view: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    ) {
        presentedMessages.append(title)
    }

    func presentInfo(message: String?, title: String, from view: ControllerBackedProtocol?) {
        presentedMessages.append(title)
    }
}

private final class StakingUnbondSetupViewModelStateSpy: StakingUnbondSetupViewModelState {
    weak var stateListener: StakingUnbondSetupModelStateListener?
    var inputAmount: Decimal? = 2.5
    var amount: Decimal? = 2.5
    var bonded: Decimal? = 10
    var fee: Decimal? = 0.1
    var builderClosure: ExtrinsicBuilderClosure?
    var confirmationFlow: StakingUnbondConfirmFlow? = .relaychain(amount: 2.5)
    var reuseIdentifier = "unbond-setup-test"

    private(set) var selectedPercentages: [Float] = []
    private(set) var updatedAmounts: [Decimal] = []
    private(set) var validatorsCallCount = 0
    private(set) var lastValidatorsLocale: Locale?

    func setStateListener(_ stateListener: StakingUnbondSetupModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        validatorsCallCount += 1
        lastValidatorsLocale = locale
        return [SucceedDataValidating()]
    }

    func selectAmountPercentage(_ percentage: Float) {
        selectedPercentages.append(percentage)
    }

    func updateAmount(_ amount: Decimal) {
        updatedAmounts.append(amount)
    }
}

private final class StakingUnbondSetupViewModelFactorySpy: StakingUnbondSetupViewModelFactoryProtocol {
    func buildBondingDurationViewModel(
        viewModelState: StakingUnbondSetupViewModelState
    ) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        LocalizableResource { _ in TitleWithSubtitleViewModel(title: "28 days", subtitle: "bonding") }
    }

    func buildCollatorViewModel(
        viewModelState: StakingUnbondSetupViewModelState,
        locale: Locale
    ) -> AccountViewModel? {
        AccountViewModel(title: "Collator", name: "collator", icon: nil)
    }

    func buildAccountViewModel(
        viewModelState: StakingUnbondSetupViewModelState,
        locale: Locale
    ) -> AccountViewModel? {
        AccountViewModel(title: "Account", name: "account", icon: nil)
    }

    func buildTitleViewModel() -> LocalizableResource<String> {
        LocalizableResource { _ in "Unbond" }
    }

    func buildNetworkFeeViewModel(
        from balanceViewModel: LocalizableResource<BalanceViewModelProtocol>
    ) -> LocalizableResource<NetworkFeeFooterViewModelProtocol> {
        LocalizableResource { _ in
            NetworkFeeFooterViewModel(
                actionTitle: LocalizableResource { _ in "Continue" },
                feeTitle: LocalizableResource { _ in "Network fee" },
                balanceViewModel: balanceViewModel
            )
        }
    }

    func buildHints() -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { _ in [TitleIconViewModel(title: "Hint", icon: nil)] }
    }
}
