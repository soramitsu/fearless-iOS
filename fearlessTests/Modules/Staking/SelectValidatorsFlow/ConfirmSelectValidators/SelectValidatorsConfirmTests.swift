import BigInt
import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class SelectValidatorsConfirmTests: XCTestCase {
    func testSetup_thenWiresStateProvidesFeeAndEstimatesFee() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertEqual(fixture.view.feeViewModel?.value(for: Locale.current).amount, "0.1")
    }

    func testStateCallbacks_thenProvideConfirmationHintsFeeAndAsset() {
        let fixture = makeFixture()

        fixture.presenter.provideConfirmationState(viewModelState: fixture.state)
        fixture.presenter.provideHints(viewModelState: fixture.state)
        fixture.presenter.provideFee(viewModelState: fixture.state)
        fixture.presenter.didReceiveAccountInfo(result: .success(WestendStub.accountInfo.item))

        XCTAssertEqual(fixture.view.confirmationViewModel?.value(for: Locale.current).senderName, "stash")
        XCTAssertEqual(fixture.view.hintsViewModel?.value(for: Locale.current).first?.title, "hint")
        XCTAssertEqual(fixture.view.feeViewModel?.value(for: Locale.current).amount, "0.1")
        XCTAssertEqual(fixture.view.assetViewModel?.value(for: Locale.current).balance, "10")
    }

    func testProceed_whenValidatorsPass_thenSubmitsNomination() {
        let fixture = makeFixture()

        fixture.presenter.proceed()

        XCTAssertEqual(fixture.interactor.submitCalls.count, 1)
    }

    func testProceed_whenFeeMissing_thenRefreshesFeeAndDoesNotSubmit() {
        let fixture = makeFixture()
        fixture.state.fee = nil

        fixture.presenter.proceed()

        XCTAssertTrue(fixture.interactor.submitCalls.isEmpty)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
    }

    func testNominationLifecycle_thenLoadingAndCompletionRoutes() {
        let fixture = makeFixture()

        fixture.presenter.didStartNomination()
        fixture.presenter.didCompleteNomination(txHash: "0xhash")

        XCTAssertTrue(fixture.view.didStartLoadingCalled)
        XCTAssertTrue(fixture.view.didStopLoadingCalled)
        XCTAssertEqual(fixture.wireframe.completedTxHash, "0xhash")
        XCTAssertEqual(fixture.wireframe.completedChainAssetId, fixture.chainAsset.identifier)
    }

    func testNominationFailure_thenStopsLoadingAndPresentsError() {
        let fixture = makeFixture()

        fixture.presenter.didFailNomination(error: SelectValidatorsConfirmError.extrinsicFailed)

        XCTAssertTrue(fixture.view.didStopLoadingCalled)
        XCTAssertNotNil(fixture.wireframe.presentedMessage)
    }

    func testAccountSelections_thenPresentAccountOptions() {
        let fixture = makeFixture()

        fixture.presenter.selectWalletAccount()
        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, WestendStub.address)

        fixture.presenter.selectPayoutAccount()
        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, fixture.state.payoutAccountAddress)

        fixture.presenter.selectCollatorAccount()
        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, fixture.state.collatorAddress)
        XCTAssertEqual(fixture.wireframe.accountOptionsChainId, fixture.chainAsset.chain.chainId)
    }

    private func makeFixture() -> SelectValidatorsConfirmFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = SelectValidatorsConfirmInteractorInputSpy()
        let wireframe = SelectValidatorsConfirmWireframeSpy()
        let state = SelectValidatorsConfirmViewModelStateSpy()
        let presenter = SelectValidatorsConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: SelectValidatorsConfirmViewModelFactorySpy(),
            viewModelState: state,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chainAsset: chainAsset,
            wallet: wallet,
            logger: LoggerSpy()
        )
        let view = SelectValidatorsConfirmViewSpy()
        presenter.view = view

        return SelectValidatorsConfirmFixture(
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

private struct SelectValidatorsConfirmFixture {
    let presenter: SelectValidatorsConfirmPresenter
    let interactor: SelectValidatorsConfirmInteractorInputSpy
    let wireframe: SelectValidatorsConfirmWireframeSpy
    let view: SelectValidatorsConfirmViewSpy
    let state: SelectValidatorsConfirmViewModelStateSpy
    let chainAsset: ChainAsset
}

private final class SelectValidatorsConfirmInteractorInputSpy:
    SelectValidatorsConfirmInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var submitCalls: [ExtrinsicBuilderClosure?] = []
    private(set) var estimateFeeCalls: [ExtrinsicBuilderClosure?] = []

    func setup() {
        didSetup = true
    }

    func submitNomination(closure: ExtrinsicBuilderClosure?) {
        submitCalls.append(closure)
    }

    func estimateFee(closure: ExtrinsicBuilderClosure?) {
        estimateFeeCalls.append(closure)
    }
}

private final class SelectValidatorsConfirmViewSpy: SelectValidatorsConfirmViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false

    private(set) var confirmationViewModel: LocalizableResource<SelectValidatorsConfirmViewModel>?
    private(set) var hintsViewModel: LocalizableResource<[TitleIconViewModel]>?
    private(set) var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private(set) var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func didReceive(confirmationViewModel: LocalizableResource<SelectValidatorsConfirmViewModel>) {
        self.confirmationViewModel = confirmationViewModel
    }

    func didReceive(hintsViewModel: LocalizableResource<[TitleIconViewModel]>) {
        self.hintsViewModel = hintsViewModel
    }

    func didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        self.assetViewModel = assetViewModel
    }

    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        self.feeViewModel = feeViewModel
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }

    func applyLocalization() {}
}

private final class SelectValidatorsConfirmViewModelStateSpy:
    SelectValidatorsConfirmViewModelState {
    weak var stateListener: SelectValidatorsConfirmModelStateListener?
    let balance: Decimal? = 10
    let amount: Decimal? = 2
    var fee: Decimal? = 0.1
    let payoutAccountAddress: String? = "5Gh52T8TzDekJsosRp22SQ4uyGi8MfuwL8qMBJ1ASF1P8r8i"
    let walletAccountAddress: String? = WestendStub.address
    let collatorAddress: String? = "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6"
    var validatorsShouldPass = true

    func setStateListener(_ stateListener: SelectValidatorsConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using _: Locale) -> [DataValidating] {
        validatorsShouldPass ? [SucceedDataValidating()] : [FailingDataValidating()]
    }

    func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        { builder in builder }
    }
}

private final class SelectValidatorsConfirmViewModelFactorySpy:
    SelectValidatorsConfirmViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState _: SelectValidatorsConfirmViewModelState
    ) throws -> LocalizableResource<SelectValidatorsConfirmViewModel>? {
        LocalizableResource { _ in
            SelectValidatorsConfirmViewModel(
                senderAddress: WestendStub.address,
                senderName: "stash",
                amount: BalanceViewModel(amount: "2", price: nil),
                rewardDestination: .restake,
                validatorsCount: 2,
                maxValidatorCount: 16,
                selectedCollatorViewModel: nil,
                stakeAmountViewModel: nil,
                poolName: nil
            )
        }
    }

    func buildHintsViewModel(
        viewModelState _: SelectValidatorsConfirmViewModelState
    ) -> LocalizableResource<[TitleIconViewModel]>? {
        LocalizableResource { _ in [TitleIconViewModel(title: "hint", icon: nil)] }
    }

    func buildFeeViewModel(
        viewModelState: SelectValidatorsConfirmViewModelState,
        priceData _: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        viewModelState.fee.map { fee in
            LocalizableResource { _ in BalanceViewModel(amount: fee.description, price: nil) }
        }
    }

    func buildAssetBalanceViewModel(
        viewModelState _: SelectValidatorsConfirmViewModelState,
        priceData _: PriceData?,
        balance: Decimal?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        LocalizableResource { _ in
            AssetBalanceViewModel(
                symbol: "UNIT",
                balance: balance?.description,
                fiatBalance: nil,
                price: nil,
                iconViewModel: nil,
                selectable: false
            )
        }
    }
}

private final class SelectValidatorsConfirmWireframeSpy:
    SelectValidatorsConfirmWireframeProtocol {
    private(set) var completedTxHash: String?
    private(set) var completedChainAssetId: String?
    private(set) var accountOptionsAddress: String?
    private(set) var accountOptionsChainId: ChainModel.Id?
    private(set) var presentedMessage: String?

    func complete(
        chainAsset: ChainAsset,
        txHash: String,
        from _: SelectValidatorsConfirmViewProtocol?
    ) {
        completedTxHash = txHash
        completedChainAssetId = chainAsset.identifier
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
        presentedMessage = "extrinsic failed"
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        presentedMessage = message
    }

    func presentInfo(message: String?, title _: String, from _: ControllerBackedProtocol?) {
        presentedMessage = message
    }
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
