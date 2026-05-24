import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingBondMoreTests: XCTestCase {
    func testSetup_whenFeeMissing_thenWiresStateProvidesViewModelsAndEstimatesFee() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertNotNil(fixture.view.inputViewModel)
        XCTAssertNil(fixture.view.feeViewModel)
        XCTAssertNotNil(fixture.view.hintsViewModel)
    }

    func testUpdateAndPercentageSelection_thenDelegateToState() {
        let fixture = makeFixture()

        fixture.presenter.updateAmount(4)
        fixture.presenter.selectAmountPercentage(0.25)

        XCTAssertEqual(fixture.state.updatedAmounts, [4])
        XCTAssertEqual(fixture.state.selectedPercentages, [0.25])
    }

    func testContinue_whenValidatorsPass_thenShowsConfirmation() {
        let fixture = makeFixture()

        fixture.presenter.handleContinueAction()

        XCTAssertEqual(fixture.wireframe.didShowConfirmation, 1)
    }

    func testContinue_whenValidatorsFail_thenDoesNotShowConfirmation() {
        let fixture = makeFixture()
        fixture.state.validatorsShouldPass = false

        fixture.presenter.handleContinueAction()

        XCTAssertEqual(fixture.wireframe.didShowConfirmation, 0)
    }

    func testModelStateCallbacks_thenUpdateViewAndRefreshFee() {
        let fixture = makeFixture()
        fixture.state.fee = 0.1

        fixture.presenter.provideFee()
        fixture.presenter.provideAccountViewModel()
        fixture.presenter.provideCollatorViewModel()
        fixture.presenter.feeParametersDidChanged(viewModelState: fixture.state)

        XCTAssertNotNil(fixture.view.feeViewModel)
        XCTAssertEqual(fixture.view.accountViewModel?.name, "stash")
        XCTAssertEqual(fixture.view.collatorViewModel?.name, "collator")
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
    }

    func testBackButton_thenDismisses() {
        let fixture = makeFixture()

        fixture.presenter.didTapBackButton()

        XCTAssertTrue(fixture.wireframe.dismissedView === fixture.view)
    }

    private func makeFixture() -> StakingBondMoreFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = StakingBondMoreInteractorInputSpy()
        let wireframe = StakingBondMoreWireframeSpy()
        let state = StakingBondMoreViewModelStateSpy()
        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            viewModelFactory: StakingBondMoreViewModelFactorySpy(),
            viewModelState: state,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            networkFeeViewModelFactory: NetworkFeeViewModelFactorySpy(),
            chainAsset: chainAsset,
            wallet: wallet,
            logger: LoggerSpy()
        )
        let view = StakingBondMoreViewSpy()
        presenter.view = view

        return StakingBondMoreFixture(
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

private struct StakingBondMoreFixture {
    let presenter: StakingBondMorePresenter
    let interactor: StakingBondMoreInteractorInputSpy
    let wireframe: StakingBondMoreWireframeSpy
    let view: StakingBondMoreViewSpy
    let state: StakingBondMoreViewModelStateSpy
}

private final class StakingBondMoreInteractorInputSpy: StakingBondMoreInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var estimateFeeCalls: [(reuseIdentifier: String?, builderClosure: ExtrinsicBuilderClosure?)] = []

    func setup() {
        didSetup = true
    }

    func estimateFee(reuseIdentifier: String?, builderClosure: ExtrinsicBuilderClosure?) {
        estimateFeeCalls.append((reuseIdentifier, builderClosure))
    }
}

private final class StakingBondMoreViewSpy: StakingBondMoreViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    private(set) var inputViewModel: LocalizableResource<IAmountInputViewModel>?
    private(set) var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private(set) var feeViewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?
    private(set) var accountViewModel: AccountViewModel?
    private(set) var collatorViewModel: AccountViewModel?
    private(set) var hintsViewModel: LocalizableResource<String>?

    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>) {
        inputViewModel = viewModel
    }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
    }

    func didReceiveFee(viewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?) {
        feeViewModel = viewModel
    }

    func didReceiveAccount(viewModel: AccountViewModel) {
        accountViewModel = viewModel
    }

    func didReceiveCollator(viewModel: AccountViewModel) {
        collatorViewModel = viewModel
    }

    func didReceiveHints(viewModel: LocalizableResource<String>?) {
        hintsViewModel = viewModel
    }

    func applyLocalization() {}
}

private final class StakingBondMoreViewModelStateSpy: StakingBondMoreViewModelState {
    weak var stateListener: StakingBondMoreModelStateListener?
    var amount: Decimal? = 2
    var fee: Decimal?
    var balance: Decimal? = 10
    let builderClosure: ExtrinsicBuilderClosure? = { builder in builder }
    let feeReuseIdentifier: String? = "bond-more-fee"
    var bondMoreConfirmationFlow: StakingBondMoreConfirmationFlow? = .relaychain(amount: 2)
    var validatorsShouldPass = true
    private(set) var updatedAmounts: [Decimal] = []
    private(set) var selectedPercentages: [Float] = []

    func setStateListener(_ stateListener: StakingBondMoreModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using _: Locale) -> [DataValidating] {
        validatorsShouldPass ? [SucceedDataValidating()] : [FailingDataValidating()]
    }

    func updateAmount(_ newValue: Decimal) {
        updatedAmounts.append(newValue)
    }

    func selectAmountPercentage(_ percentage: Float) {
        selectedPercentages.append(percentage)
    }
}

private final class StakingBondMoreViewModelFactorySpy: StakingBondMoreViewModelFactoryProtocol {
    func buildCollatorViewModel(viewModelState _: StakingBondMoreViewModelState, locale _: Locale) -> AccountViewModel? {
        AccountViewModel(title: "Collator", name: "collator", icon: nil)
    }

    func buildAccountViewModel(viewModelState _: StakingBondMoreViewModelState, locale _: Locale) -> AccountViewModel? {
        AccountViewModel(title: "Account", name: "stash", icon: nil)
    }

    func buildHintViewModel(viewModelState _: StakingBondMoreViewModelState, locale _: Locale) -> LocalizableResource<String>? {
        LocalizableResource { _ in "hint" }
    }
}

private final class NetworkFeeViewModelFactorySpy: NetworkFeeViewModelFactoryProtocol {
    func createViewModel(
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
}

private final class StakingBondMoreWireframeSpy: StakingBondMoreWireframeProtocol {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) var didShowConfirmation = 0
    private(set) var didPresentAmountTooHigh = false

    func showConfirmation(
        from _: ControllerBackedProtocol?,
        flow _: StakingBondMoreConfirmationFlow,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        didShowConfirmation += 1
    }

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {
        didPresentAmountTooHigh = true
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
