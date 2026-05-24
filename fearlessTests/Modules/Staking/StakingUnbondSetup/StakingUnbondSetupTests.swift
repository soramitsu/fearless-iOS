import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingUnbondSetupTests: XCTestCase {
    func testSetup_thenWiresStateProvidesViewModelsAndStartsInteractor() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertNotNil(fixture.view.inputViewModel)
        XCTAssertNotNil(fixture.view.assetViewModel)
        XCTAssertNil(fixture.view.feeViewModel)
        XCTAssertEqual(fixture.view.titleViewModel?.value(for: Locale.current), "Unbond")
        XCTAssertEqual(fixture.view.accountViewModel?.name, "stash")
        XCTAssertEqual(fixture.view.collatorViewModel?.name, "collator")
        XCTAssertEqual(fixture.view.hintsViewModel?.value(for: Locale.current).first?.title, "hint")
    }

    func testUpdateAndPercentageSelection_thenDelegateToState() {
        let fixture = makeFixture()

        fixture.presenter.updateAmount(4)
        fixture.presenter.selectAmountPercentage(0.75)

        XCTAssertEqual(fixture.state.updatedAmounts, [4])
        XCTAssertEqual(fixture.state.selectedPercentages, [0.75])
    }

    func testProceed_whenValidatorsPass_thenRoutesToConfirm() {
        let fixture = makeFixture()

        fixture.presenter.proceed()

        XCTAssertEqual(fixture.wireframe.didProceed, 1)
    }

    func testProceed_whenValidatorsFail_thenDoesNotRoute() {
        let fixture = makeFixture()
        fixture.state.validatorsShouldPass = false

        fixture.presenter.proceed()

        XCTAssertEqual(fixture.wireframe.didProceed, 0)
    }

    func testModelStateCallbacks_thenRefreshFeeAndProvideFee() {
        let fixture = makeFixture()
        fixture.state.fee = 0.1

        fixture.presenter.provideFeeViewModel()
        fixture.presenter.updateFeeIfNeeded()

        XCTAssertNotNil(fixture.view.feeViewModel)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.first?.reuseIdentifier, "unbond-fee")
    }

    func testCloseAndBack_thenRouteThroughWireframe() {
        let fixture = makeFixture()

        fixture.presenter.close()
        fixture.presenter.didTapBackButton()

        XCTAssertTrue(fixture.wireframe.closedView === fixture.view)
        XCTAssertTrue(fixture.wireframe.dismissedView === fixture.view)
    }

    private func makeFixture() -> StakingUnbondSetupFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = StakingUnbondSetupInteractorInputSpy()
        let wireframe = StakingUnbondSetupWireframeSpy()
        let state = StakingUnbondSetupViewModelStateSpy()
        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            viewModelFactory: StakingUnbondSetupViewModelFactorySpy(),
            viewModelState: state,
            chainAsset: chainAsset,
            wallet: wallet,
            logger: LoggerSpy()
        )
        let view = StakingUnbondSetupViewSpy()
        presenter.view = view

        return StakingUnbondSetupFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            state: state
        )
    }

    private func makeChainAsset() -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 0,
            addressPrefix: 42,
            assetPresicion: 12,
            staking: .relayChain
        )
        let asset = AssetModel(
            id: "unit",
            name: "Unit",
            symbol: "UNIT",
            precision: 12,
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            type: .normal
        )
        chain.assets = [asset]

        return ChainAsset(chain: chain, asset: asset)
    }
}

private struct StakingUnbondSetupFixture {
    let presenter: StakingUnbondSetupPresenter
    let interactor: StakingUnbondSetupInteractorInputSpy
    let wireframe: StakingUnbondSetupWireframeSpy
    let view: StakingUnbondSetupViewSpy
    let state: StakingUnbondSetupViewModelStateSpy
}

private final class StakingUnbondSetupInteractorInputSpy: StakingUnbondSetupInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var estimateFeeCalls: [(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String)] = []

    func setup() {
        didSetup = true
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String) {
        estimateFeeCalls.append((builderClosure, reuseIdentifier))
    }
}

private final class StakingUnbondSetupViewSpy: StakingUnbondSetupViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    private(set) var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private(set) var feeViewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?
    private(set) var inputViewModel: LocalizableResource<IAmountInputViewModel>?
    private(set) var bondingDurationViewModel: LocalizableResource<TitleWithSubtitleViewModel>?
    private(set) var accountViewModel: AccountViewModel?
    private(set) var collatorViewModel: AccountViewModel?
    private(set) var titleViewModel: LocalizableResource<String>?
    private(set) var hintsViewModel: LocalizableResource<[TitleIconViewModel]>?

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
    }

    func didReceiveFee(viewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?) {
        feeViewModel = viewModel
    }

    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>) {
        inputViewModel = viewModel
    }

    func didReceiveBonding(duration: LocalizableResource<TitleWithSubtitleViewModel>) {
        bondingDurationViewModel = duration
    }

    func didReceiveAccount(viewModel: AccountViewModel) {
        accountViewModel = viewModel
    }

    func didReceiveCollator(viewModel: AccountViewModel) {
        collatorViewModel = viewModel
    }

    func didReceiveTitle(viewModel: LocalizableResource<String>) {
        titleViewModel = viewModel
    }

    func didReceiveHints(viewModel: LocalizableResource<[TitleIconViewModel]>) {
        hintsViewModel = viewModel
    }

    func applyLocalization() {}
}

private final class StakingUnbondSetupViewModelStateSpy: StakingUnbondSetupViewModelState {
    weak var stateListener: StakingUnbondSetupModelStateListener?
    let inputAmount: Decimal? = 2
    let amount: Decimal? = 2
    let bonded: Decimal? = 10
    var fee: Decimal?
    let builderClosure: ExtrinsicBuilderClosure? = { builder in builder }
    let confirmationFlow: StakingUnbondConfirmFlow? = .relaychain(amount: 2)
    let reuseIdentifier = "unbond-fee"
    var validatorsShouldPass = true
    private(set) var updatedAmounts: [Decimal] = []
    private(set) var selectedPercentages: [Float] = []

    func setStateListener(_ stateListener: StakingUnbondSetupModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using _: Locale) -> [DataValidating] {
        validatorsShouldPass ? [SucceedDataValidating()] : [FailingDataValidating()]
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
        viewModelState _: StakingUnbondSetupViewModelState
    ) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        LocalizableResource { _ in TitleWithSubtitleViewModel(title: "Bonding", subtitle: "28 days") }
    }

    func buildCollatorViewModel(
        viewModelState _: StakingUnbondSetupViewModelState,
        locale _: Locale
    ) -> AccountViewModel? {
        AccountViewModel(title: "Collator", name: "collator", icon: nil)
    }

    func buildAccountViewModel(
        viewModelState _: StakingUnbondSetupViewModelState,
        locale _: Locale
    ) -> AccountViewModel? {
        AccountViewModel(title: "Account", name: "stash", icon: nil)
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
                feeTitle: LocalizableResource { _ in "Fee" },
                balanceViewModel: balanceViewModel
            )
        }
    }

    func buildHints() -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { _ in [TitleIconViewModel(title: "hint", icon: nil)] }
    }
}

private final class StakingUnbondSetupWireframeSpy: StakingUnbondSetupWireframeProtocol {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var closedView: StakingUnbondSetupViewProtocol?
    private(set) var didProceed = 0

    func close(view: StakingUnbondSetupViewProtocol?) {
        closedView = view
    }

    func proceed(
        view _: StakingUnbondSetupViewProtocol?,
        flow _: StakingUnbondConfirmFlow,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        didProceed += 1
    }

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}

    func showWeb(url _: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) {}
}

private final class FailingDataValidating: DataValidating {
    func validate(notifying _: DataValidatingDelegate) -> DataValidationProblem? {
        .error
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
