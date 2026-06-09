import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingRebondConfirmationTests: XCTestCase {
    func testSetup_thenWiresStateProvidesViewModelsAndEstimatesFee() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertEqual(fixture.view.confirmationViewModel?.amount.value(for: Locale.current), "2 UNIT")
        XCTAssertEqual(fixture.view.assetViewModel?.value(for: Locale.current).balance, "5")
        XCTAssertEqual(fixture.view.feeViewModel?.value(for: Locale.current).amount, "0.1")
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
        successFixture.presenter.didSubmitRebonding(result: .success("0xhash"))

        XCTAssertTrue(successFixture.view.didStopLoadingCalled)
        XCTAssertTrue(successFixture.wireframe.completedView === successFixture.view)

        let failureFixture = makeFixture()
        failureFixture.presenter.didSubmitRebonding(result: .failure(TestError.expected))

        XCTAssertTrue(failureFixture.view.didStopLoadingCalled)
        XCTAssertTrue(failureFixture.wireframe.didPresentExtrinsicFailed)
    }

    func testFeeParametersChanged_thenEstimatesFeeAgain() {
        let fixture = makeFixture()

        fixture.presenter.feeParametersDidChanged()

        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.first?.reuseIdentifier, "rebond-confirm-fee")
    }

    func testSelectAccount_whenAddressAvailable_thenPresentsAccountOptions() {
        let fixture = makeFixture()

        fixture.presenter.selectAccount()

        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, WestendStub.address)
        XCTAssertEqual(fixture.wireframe.accountOptionsChainId, fixture.chainAsset.chain.chainId)
    }

    private func makeFixture() -> StakingRebondConfirmationFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = StakingRebondConfirmationInteractorInputSpy()
        let wireframe = StakingRebondConfirmationWireframeSpy()
        let state = StakingRebondConfirmationViewModelStateSpy()
        let presenter = StakingRebondConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: StakingRebondConfirmationViewModelFactorySpy(),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chainAsset: chainAsset,
            viewModelState: state,
            wallet: wallet,
            logger: LoggerSpy()
        )
        let view = StakingRebondConfirmationViewSpy()
        presenter.view = view

        return StakingRebondConfirmationFixture(
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

private struct StakingRebondConfirmationFixture {
    let presenter: StakingRebondConfirmationPresenter
    let interactor: StakingRebondConfirmationInteractorInputSpy
    let wireframe: StakingRebondConfirmationWireframeSpy
    let view: StakingRebondConfirmationViewSpy
    let state: StakingRebondConfirmationViewModelStateSpy
    let chainAsset: ChainAsset
}

private final class StakingRebondConfirmationInteractorInputSpy:
    StakingRebondConfirmationInteractorInputProtocol {
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

private final class StakingRebondConfirmationViewSpy: StakingRebondConfirmationViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false

    private(set) var confirmationViewModel: StakingRebondConfirmationViewModel?
    private(set) var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private(set) var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func didReceiveConfirmation(viewModel: StakingRebondConfirmationViewModel) {
        confirmationViewModel = viewModel
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

private final class StakingRebondConfirmationViewModelStateSpy:
    StakingRebondConfirmationViewModelState {
    weak var stateListener: StakingRebondConfirmationModelStateListener?
    let builderClosure: ExtrinsicBuilderClosure? = { builder in builder }
    let reuseIdentifier: String? = "rebond-confirm-fee"
    let selectableAccountAddress: String? = WestendStub.address
    var validatorsShouldPass = true

    func setStateListener(_ stateListener: StakingRebondConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }

    func dataValidators(locale _: Locale) -> [DataValidating] {
        validatorsShouldPass ? [SucceedDataValidating()] : [FailingDataValidating()]
    }
}

private final class StakingRebondConfirmationViewModelFactorySpy:
    StakingRebondConfirmationViewModelFactoryProtocol {
    func createViewModel(
        viewModelState _: StakingRebondConfirmationViewModelState
    ) -> StakingRebondConfirmationViewModel? {
        StakingRebondConfirmationViewModel(
            senderAddress: WestendStub.address,
            senderIcon: nil,
            senderName: "stash",
            amount: LocalizableResource { _ in "2 UNIT" }
        )
    }

    func createFeeViewModel(
        viewModelState _: StakingRebondConfirmationViewModelState,
        priceData _: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        LocalizableResource { _ in BalanceViewModel(amount: "0.1", price: nil) }
    }

    func createAssetBalanceViewModel(
        viewModelState _: StakingRebondConfirmationViewModelState,
        priceData _: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        LocalizableResource { _ in
            AssetBalanceViewModel(
                symbol: "UNIT",
                balance: "5",
                fiatBalance: nil,
                price: nil,
                iconViewModel: nil,
                selectable: false
            )
        }
    }
}

private final class StakingRebondConfirmationWireframeSpy:
    StakingRebondConfirmationWireframeProtocol {
    private(set) weak var completedView: StakingRebondConfirmationViewProtocol?
    private(set) var didPresentExtrinsicFailed = false
    private(set) var accountOptionsAddress: String?
    private(set) var accountOptionsChainId: ChainModel.Id?

    func complete(from view: StakingRebondConfirmationViewProtocol?) {
        completedView = view
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
