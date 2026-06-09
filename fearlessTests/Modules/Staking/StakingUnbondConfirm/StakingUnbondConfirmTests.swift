import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingUnbondConfirmTests: XCTestCase {
    func testSetup_whenFeeMissing_thenWiresStateProvidesViewModelsAndEstimatesFee() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertNotNil(fixture.view.assetViewModel)
        XCTAssertNil(fixture.view.feeViewModel)
        XCTAssertEqual(fixture.view.confirmationViewModel?.senderAddress, WestendStub.address)
        XCTAssertEqual(fixture.view.confirmationViewModel?.amountString.value(for: Locale.current), "2 UNIT")
        XCTAssertEqual(fixture.view.bondingDurationViewModel?.value(for: Locale.current).subtitle, "28 days")
    }

    func testConfirm_whenValidatorsPass_thenStartsLoadingAndSubmits() {
        let fixture = makeFixture()

        fixture.presenter.confirm()

        XCTAssertTrue(fixture.view.didStartLoadingCalled)
        XCTAssertEqual(fixture.interactor.submitCalls.count, 1)
    }

    func testConfirm_whenValidatorsFail_thenDoesNotSubmit() {
        let fixture = makeFixture()
        fixture.state.validatorsShouldPass = false

        fixture.presenter.confirm()

        XCTAssertFalse(fixture.view.didStartLoadingCalled)
        XCTAssertTrue(fixture.interactor.submitCalls.isEmpty)
    }

    func testSubmitResult_whenSuccessAndFailure_thenStopsLoadingAndRoutes() {
        let successFixture = makeFixture()
        successFixture.presenter.didSubmitUnbonding(result: .success("0xhash"))

        XCTAssertTrue(successFixture.view.didStopLoadingCalled)
        XCTAssertEqual(successFixture.wireframe.completedHash, "0xhash")

        let failureFixture = makeFixture()
        failureFixture.presenter.didSubmitUnbonding(result: .failure(TestError.expected))

        XCTAssertTrue(failureFixture.view.didStopLoadingCalled)
        XCTAssertTrue(failureFixture.wireframe.didPresentExtrinsicFailed)
    }

    func testModelStateCallbacks_thenProvideFeeAndRefreshFallbackFee() {
        let fixture = makeFixture()
        fixture.state.fee = 0.1

        fixture.presenter.provideFeeViewModel()
        fixture.presenter.didReceiveFeeError()

        XCTAssertNotNil(fixture.view.feeViewModel)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.first?.reuseIdentifier, "unbond-confirm-fee")
    }

    func testSelectAccount_whenAddressAvailable_thenPresentsAccountOptions() {
        let fixture = makeFixture()

        fixture.presenter.selectAccount()

        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, WestendStub.address)
        XCTAssertEqual(fixture.wireframe.accountOptionsChainId, fixture.chainAsset.chain.chainId)
    }

    func testBackButton_thenDismisses() {
        let fixture = makeFixture()

        fixture.presenter.didTapBackButton()

        XCTAssertTrue(fixture.wireframe.dismissedView === fixture.view)
    }

    private func makeFixture() -> StakingUnbondConfirmFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = StakingUnbondConfirmInteractorInputSpy()
        let wireframe = StakingUnbondConfirmWireframeSpy()
        let state = StakingUnbondConfirmViewModelStateSpy()
        let presenter = StakingUnbondConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: StakingUnbondConfirmViewModelFactorySpy(),
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            viewModelState: state,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chainAsset: chainAsset,
            wallet: wallet,
            logger: LoggerSpy()
        )
        let view = StakingUnbondConfirmViewSpy()
        presenter.view = view

        return StakingUnbondConfirmFixture(
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

private struct StakingUnbondConfirmFixture {
    let presenter: StakingUnbondConfirmPresenter
    let interactor: StakingUnbondConfirmInteractorInputSpy
    let wireframe: StakingUnbondConfirmWireframeSpy
    let view: StakingUnbondConfirmViewSpy
    let state: StakingUnbondConfirmViewModelStateSpy
    let chainAsset: ChainAsset
}

private final class StakingUnbondConfirmInteractorInputSpy: StakingUnbondConfirmInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var estimateFeeCalls: [(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)] = []
    private(set) var submitCalls: [ExtrinsicBuilderClosure?] = []

    func setup() {
        didSetup = true
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        estimateFeeCalls.append((builderClosure, reuseIdentifier))
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        submitCalls.append(builderClosure)
    }
}

private final class StakingUnbondConfirmViewSpy: StakingUnbondConfirmViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false

    private(set) var confirmationViewModel: StakingUnbondConfirmViewModel?
    private(set) var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private(set) var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private(set) var bondingDurationViewModel: LocalizableResource<TitleWithSubtitleViewModel>?
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func didReceiveConfirmation(viewModel: StakingUnbondConfirmViewModel) {
        confirmationViewModel = viewModel
    }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
    }

    func didReceiveBonding(duration: LocalizableResource<TitleWithSubtitleViewModel>) {
        bondingDurationViewModel = duration
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }

    func applyLocalization() {}
}

private final class StakingUnbondConfirmViewModelStateSpy: StakingUnbondConfirmViewModelState {
    weak var stateListener: StakingUnbondConfirmModelStateListener?
    let inputAmount: Decimal = 2
    let bonded: Decimal? = 10
    var fee: Decimal?
    let accountAddress: AccountAddress? = WestendStub.address
    let builderClosure: ExtrinsicBuilderClosure? = { builder in builder }
    let builderClosureOld: ExtrinsicBuilderClosure? = { builder in builder }
    let reuseIdentifier: String? = "unbond-confirm-fee"
    var validatorsShouldPass = true

    func setStateListener(_ stateListener: StakingUnbondConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using _: Locale) -> [DataValidating] {
        validatorsShouldPass ? [SucceedDataValidating()] : [FailingDataValidating()]
    }
}

private final class StakingUnbondConfirmViewModelFactorySpy: StakingUnbondConfirmViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: StakingUnbondConfirmViewModelState
    ) -> StakingUnbondConfirmViewModel? {
        StakingUnbondConfirmViewModel(
            senderAddress: viewModelState.accountAddress ?? "",
            senderIcon: nil,
            senderName: "stash",
            collatorName: nil,
            collatorIcon: nil,
            stakeAmountViewModel: nil,
            amountString: LocalizableResource { _ in "\(viewModelState.inputAmount) UNIT" },
            hints: LocalizableResource { _ in [TitleIconViewModel(title: "hint", icon: nil)] }
        )
    }

    func buildBondingDurationViewModel(
        viewModelState _: StakingUnbondConfirmViewModelState
    ) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        LocalizableResource { _ in TitleWithSubtitleViewModel(title: "Bonding", subtitle: "28 days") }
    }
}

private final class StakingUnbondConfirmWireframeSpy: StakingUnbondConfirmWireframeProtocol {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) var completedHash: String?
    private(set) var completedChainAssetId: ChainModel.Id?
    private(set) var didPresentExtrinsicFailed = false
    private(set) var accountOptionsAddress: String?
    private(set) var accountOptionsChainId: ChainModel.Id?

    func complete(
        on _: ControllerBackedProtocol?,
        hash: String,
        chainAsset: ChainAsset
    ) {
        completedHash = hash
        completedChainAssetId = chainAsset.chain.chainId
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

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {
        didPresentExtrinsicFailed = true
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

private enum TestError: Error {
    case expected
}
