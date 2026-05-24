import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingPayoutsConfirmTests: XCTestCase {
    func testSetup_thenWiresStateProvidesFeeAndEstimatesFee() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertEqual(fixture.view.feeViewModel?.value(for: Locale.current).amount, "0.1")
    }

    func testProvideViewModel_thenSendsListAndSingleModels() {
        let fixture = makeFixture()

        fixture.presenter.provideViewModel()

        XCTAssertEqual(fixture.view.viewModels.count, 1)
        XCTAssertEqual(fixture.view.singleViewModel?.senderAddress, WestendStub.address)
        XCTAssertEqual(fixture.view.singleViewModel?.amountString.value(for: Locale.current), "2 UNIT")
    }

    func testProceed_whenValidatorsPass_thenSubmitsPayout() {
        let fixture = makeFixture()

        fixture.presenter.proceed()

        XCTAssertEqual(fixture.interactor.submitCalls.count, 1)
    }

    func testProceed_whenValidatorsFail_thenDoesNotSubmit() {
        let fixture = makeFixture()
        fixture.state.validatorsShouldPass = false

        fixture.presenter.proceed()

        XCTAssertTrue(fixture.interactor.submitCalls.isEmpty)
    }

    func testPayoutLifecycle_whenSuccess_thenStopsLoadingAndCompletes() {
        let batchFixture = makeFixture()
        batchFixture.presenter.didStartPayout()
        batchFixture.presenter.didCompletePayout(txHashes: ["0x1", "0x2"])

        XCTAssertTrue(batchFixture.view.didStartLoadingCalled)
        XCTAssertTrue(batchFixture.view.didStopLoadingCalled)
        XCTAssertTrue(batchFixture.wireframe.completedView === batchFixture.view)

        let singleFixture = makeFixture()
        singleFixture.presenter.didCompletePayout(result: .success("0xhash"))

        XCTAssertTrue(singleFixture.view.didStopLoadingCalled)
        XCTAssertTrue(singleFixture.wireframe.completedView === singleFixture.view)
    }

    func testPayoutFailure_thenStopsLoadingAndPresentsError() {
        let fixture = makeFixture()

        fixture.presenter.didFailPayout(error: TestError.expected)

        XCTAssertTrue(fixture.view.didStopLoadingCalled)
        XCTAssertTrue(fixture.wireframe.didPresentError)
    }

    func testAccountOptionsAndBack_thenRouteThroughWireframe() {
        let fixture = makeFixture()
        let account = AccountInfoViewModel(title: "", address: WestendStub.address, name: "stash", icon: nil)

        fixture.presenter.presentAccountOptions(for: account)
        fixture.presenter.didTapBackButton()

        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, WestendStub.address)
        XCTAssertEqual(fixture.wireframe.accountOptionsChainId, fixture.chainAsset.chain.chainId)
        XCTAssertTrue(fixture.wireframe.dismissedView === fixture.view)
    }

    private func makeFixture() -> StakingPayoutsConfirmFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = StakingPayoutConfirmationInteractorInputSpy()
        let wireframe = StakingPayoutConfirmationWireframeSpy()
        let state = StakingPayoutConfirmationViewModelStateSpy()
        let presenter = StakingPayoutConfirmationPresenter(
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            payoutConfirmViewModelFactory: StakingPayoutConfirmationViewModelFactorySpy(),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chainAsset: chainAsset,
            logger: LoggerSpy(),
            viewModelState: state,
            wallet: wallet
        )
        let view = StakingPayoutConfirmationViewSpy()
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        return StakingPayoutsConfirmFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            state: state,
            chainAsset: chainAsset
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

private struct StakingPayoutsConfirmFixture {
    let presenter: StakingPayoutConfirmationPresenter
    let interactor: StakingPayoutConfirmationInteractorInputSpy
    let wireframe: StakingPayoutConfirmationWireframeSpy
    let view: StakingPayoutConfirmationViewSpy
    let state: StakingPayoutConfirmationViewModelStateSpy
    let chainAsset: ChainAsset
}

private final class StakingPayoutConfirmationInteractorInputSpy:
    StakingPayoutConfirmationInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var estimateFeeCalls: [ExtrinsicBuilderClosure?] = []
    private(set) var submitCalls: [ExtrinsicBuilderClosure?] = []

    func setup() {
        didSetup = true
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?) {
        estimateFeeCalls.append(builderClosure)
    }

    func submitPayout(builderClosure: ExtrinsicBuilderClosure?) {
        submitCalls.append(builderClosure)
    }
}

private final class StakingPayoutConfirmationViewSpy:
    StakingPayoutConfirmationViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false

    private(set) var viewModels: [LocalizableResource<PayoutConfirmViewModel>] = []
    private(set) var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private(set) var singleViewModel: StakingPayoutConfirmationViewModel?
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func didRecieve(viewModel: [LocalizableResource<PayoutConfirmViewModel>]) {
        viewModels = viewModel
    }

    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        self.feeViewModel = feeViewModel
    }

    func didReceive(singleViewModel: StakingPayoutConfirmationViewModel?) {
        self.singleViewModel = singleViewModel
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }

    func applyLocalization() {}
}

private final class StakingPayoutConfirmationViewModelStateSpy:
    StakingPayoutConfirmationViewModelState {
    weak var stateListener: StakingPayoutConfirmationModelStateListener?
    var fee: Decimal? = 0.1
    let builderClosure: ExtrinsicBuilderClosure? = { builder in builder }
    var validatorsShouldPass = true

    func setStateListener(_ stateListener: StakingPayoutConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using _: Locale) -> [DataValidating] {
        validatorsShouldPass ? [SucceedDataValidating()] : [FailingDataValidating()]
    }
}

private final class StakingPayoutConfirmationViewModelFactorySpy:
    StakingPayoutConfirmationViewModelFactoryProtocol {
    func createPayoutConfirmViewModel(
        viewModelState _: StakingPayoutConfirmationViewModelState,
        priceData _: PriceData?
    ) -> [LocalizableResource<PayoutConfirmViewModel>] {
        [
            LocalizableResource { _ in
                .accountInfo(AccountInfoViewModel(title: "Account", address: WestendStub.address, name: "stash", icon: nil))
            }
        ]
    }

    func createSinglePayoutConfirmationViewModel(
        viewModelState _: StakingPayoutConfirmationViewModelState,
        priceData _: PriceData?
    ) -> StakingPayoutConfirmationViewModel? {
        StakingPayoutConfirmationViewModel(
            senderAddress: WestendStub.address,
            senderIcon: nil,
            senderName: "stash",
            amount: nil,
            amountString: LocalizableResource { _ in "2 UNIT" }
        )
    }
}

private final class StakingPayoutConfirmationWireframeSpy:
    StakingPayoutConfirmationWireframeProtocol {
    private(set) weak var completedView: StakingPayoutConfirmationViewProtocol?
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) var accountOptionsAddress: String?
    private(set) var accountOptionsChainId: ChainModel.Id?
    private(set) var didPresentError = false

    func complete(from view: StakingPayoutConfirmationViewProtocol?) {
        completedView = view
    }

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func presentAccountOptions(
        from _: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        locale _: Locale,
        exportClosure _: (() -> Void)?
    ) {
        accountOptionsAddress = address
        accountOptionsChainId = chain.chainId
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        didPresentError = true
        return true
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

private enum TestError: Error {
    case expected
}
