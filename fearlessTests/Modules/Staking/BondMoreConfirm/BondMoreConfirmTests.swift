import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class BondMoreConfirmTests: XCTestCase {
    func testSetup_whenFeeMissing_thenWiresStateProvidesViewModelsAndEstimatesFee() {
        let fixture = makeFixture()
        let confirmationExpectation = expectation(description: "confirmation view model")
        fixture.view.onConfirmation = { confirmationExpectation.fulfill() }

        fixture.presenter.setup()

        wait(for: [confirmationExpectation], timeout: 1)
        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertNotNil(fixture.view.assetViewModel)
        XCTAssertNil(fixture.view.feeViewModel)
        XCTAssertEqual(fixture.view.confirmationViewModel?.amountViewModel?.subtitle, "2")
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
        successFixture.presenter.didSubmitBonding(result: .success("0xhash"))

        XCTAssertTrue(successFixture.view.didStopLoadingCalled)
        XCTAssertEqual(successFixture.wireframe.completedHash, "0xhash")

        let failureFixture = makeFixture()
        failureFixture.presenter.didSubmitBonding(result: .failure(TestError.expected))

        XCTAssertTrue(failureFixture.view.didStopLoadingCalled)
        XCTAssertTrue(failureFixture.wireframe.didPresentExtrinsicFailed)
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

    private func makeFixture() -> BondMoreConfirmFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = StakingBondMoreConfirmationInteractorInputSpy()
        let wireframe = StakingBondMoreConfirmationWireframeSpy()
        let state = StakingBondMoreConfirmationViewModelStateSpy()
        let presenter = StakingBondMoreConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: StakingBondMoreConfirmViewModelFactorySpy(),
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            viewModelState: state,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chainAsset: chainAsset,
            wallet: wallet,
            logger: LoggerSpy()
        )
        let view = StakingBondMoreConfirmationViewSpy()
        presenter.view = view

        return BondMoreConfirmFixture(
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

private struct BondMoreConfirmFixture {
    let presenter: StakingBondMoreConfirmationPresenter
    let interactor: StakingBondMoreConfirmationInteractorInputSpy
    let wireframe: StakingBondMoreConfirmationWireframeSpy
    let view: StakingBondMoreConfirmationViewSpy
    let state: StakingBondMoreConfirmationViewModelStateSpy
    let chainAsset: ChainAsset
}

private final class StakingBondMoreConfirmationInteractorInputSpy:
    StakingBondMoreConfirmationInteractorInputProtocol {
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

private final class StakingBondMoreConfirmationViewSpy: StakingBondMoreConfirmationViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false
    var onConfirmation: (() -> Void)?

    private(set) var confirmationViewModel: StakingBondMoreConfirmViewModel?
    private(set) var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private(set) var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func didReceiveConfirmation(viewModel: StakingBondMoreConfirmViewModel) {
        confirmationViewModel = viewModel
        onConfirmation?()
    }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }

    func applyLocalization() {}
}

private final class StakingBondMoreConfirmationViewModelStateSpy:
    StakingBondMoreConfirmationViewModelState {
    weak var stateListener: StakingBondMoreConfirmationModelStateListener?
    let amount: Decimal = 2
    var fee: Decimal?
    let balance: Decimal? = 10
    let accountAddress: String? = WestendStub.address
    let builderClosure: ExtrinsicBuilderClosure? = { builder in builder }
    let feeReuseIdentifier: String? = "bond-more-confirm-fee"
    var validatorsShouldPass = true

    func setStateListener(_ stateListener: StakingBondMoreConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using _: Locale) -> [DataValidating] {
        validatorsShouldPass ? [SucceedDataValidating()] : [FailingDataValidating()]
    }
}

private final class StakingBondMoreConfirmViewModelFactorySpy:
    StakingBondMoreConfirmViewModelFactoryProtocol {
    func createViewModel(
        account _: MetaAccountModel,
        amount: Decimal,
        state _: StakingBondMoreConfirmationViewModelState,
        locale _: Locale,
        priceData _: PriceData?
    ) throws -> StakingBondMoreConfirmViewModel? {
        StakingBondMoreConfirmViewModel(
            accountViewModel: TitleMultiValueViewModel(title: "Account", subtitle: "stash"),
            amountViewModel: TitleMultiValueViewModel(title: "Amount", subtitle: "\(amount)"),
            collatorViewModel: nil,
            senderIcon: nil,
            amount: nil,
            collatorIcon: nil
        )
    }
}

private final class StakingBondMoreConfirmationWireframeSpy:
    StakingBondMoreConfirmationWireframeProtocol {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) var completedHash: String?
    private(set) var didPresentExtrinsicFailed = false
    private(set) var accountOptionsAddress: String?
    private(set) var accountOptionsChainId: ChainModel.Id?

    func complete(
        from _: StakingBondMoreConfirmationViewProtocol,
        chainAsset _: ChainAsset,
        extrinsicHash: String
    ) {
        completedHash = extrinsicHash
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
