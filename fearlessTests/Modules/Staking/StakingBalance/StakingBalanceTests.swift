import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingBalanceTests: XCTestCase {
    func testSetupAndRefresh_whenCalled_thenWiresStateAndInteractor() {
        let fixture = makeFixture()

        fixture.presenter.setup()
        fixture.state.notifyChange()
        fixture.presenter.handleRefresh()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertTrue(fixture.interactor.didRefresh)
        XCTAssertEqual(fixture.view.reloadedViewModel?.title, "staking balance")
        XCTAssertNil(fixture.viewModelFactory.receivedPriceData)
    }

    func testActions_whenValidatorsPass_thenRoutesToExpectedFlows() {
        let fixture = makeFixture()

        fixture.presenter.handleAction(.bondMore)
        fixture.presenter.handleAction(.unbond)
        fixture.presenter.handleAction(.redeem)
        fixture.presenter.handleUnbondingMoreAction()

        XCTAssertEqual(fixture.wireframe.didShowBondMore, 1)
        XCTAssertEqual(fixture.wireframe.didShowUnbond, 1)
        XCTAssertEqual(fixture.wireframe.didShowRedeem, 1)
        XCTAssertEqual(fixture.wireframe.presentedRebondViewModel?.actions.count, 2)
    }

    func testActions_whenValidatorsFail_thenDoNotRoute() {
        let fixture = makeFixture()
        fixture.state.validatorsShouldPass = false

        fixture.presenter.handleAction(.bondMore)
        fixture.presenter.handleAction(.unbond)
        fixture.presenter.handleAction(.redeem)
        fixture.presenter.handleUnbondingMoreAction()

        XCTAssertEqual(fixture.wireframe.didShowBondMore, 0)
        XCTAssertEqual(fixture.wireframe.didShowUnbond, 0)
        XCTAssertEqual(fixture.wireframe.didShowRedeem, 0)
        XCTAssertNil(fixture.wireframe.presentedRebondViewModel)
    }

    func testRebondSheetAction_whenSelected_thenDelegatesDecisionToState() throws {
        let fixture = makeFixture()

        fixture.presenter.handleUnbondingMoreAction()
        let action = try XCTUnwrap(fixture.wireframe.presentedRebondViewModel?.actions.first)
        action.handler?()

        XCTAssertEqual(fixture.state.decidedRebondOption, .all)
    }

    func testModelStateCallbacks_thenRouteFinishAndRebondFlows() {
        let fixture = makeFixture()

        fixture.presenter.finishFlow()
        fixture.presenter.decideShowSetupRebondFlow()
        fixture.presenter.decideShowConfirmRebondFlow(flow: .relaychain(variant: .last))

        XCTAssertTrue(fixture.wireframe.cancelledView === fixture.view)
        XCTAssertEqual(fixture.wireframe.didShowRebondSetup, 1)
        XCTAssertEqual(fixture.wireframe.didShowRebondConfirm, 1)
    }

    private func makeFixture() -> StakingBalanceFixture {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 0,
            addressPrefix: 42,
            assetPresicion: 12,
            hasCrowdloans: false
        )
        let asset = AssetModel(
            id: "unit",
            name: "Unit",
            symbol: "UNIT",
            precision: 12,
            price: 1.25,
            fiatDayChange: 0.01,
            isUtility: true,
            isNative: true
        )
        chain.assets = [asset]

        let interactor = StakingBalanceInteractorInputSpy()
        let wireframe = StakingBalanceWireframeSpy()
        let viewModelFactory = StakingBalanceViewModelFactorySpy()
        let viewModelState = StakingBalanceViewModelStateSpy()
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let wallet = AccountGenerator.generateMetaAccount()
        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            viewModelState: viewModelState,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chainAsset: chainAsset,
            wallet: wallet
        )
        let view = StakingBalanceViewSpy()
        presenter.view = view

        return StakingBalanceFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            viewModelFactory: viewModelFactory,
            state: viewModelState
        )
    }
}

private struct StakingBalanceFixture {
    let presenter: StakingBalancePresenter
    let interactor: StakingBalanceInteractorInputSpy
    let wireframe: StakingBalanceWireframeSpy
    let view: StakingBalanceViewSpy
    let viewModelFactory: StakingBalanceViewModelFactorySpy
    let state: StakingBalanceViewModelStateSpy
}

private final class StakingBalanceInteractorInputSpy: StakingBalanceInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var didRefresh = false

    func setup() {
        didSetup = true
    }

    func refresh() {
        didRefresh = true
    }
}

private final class StakingBalanceViewSpy: StakingBalanceViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false

    private(set) var reloadedViewModel: StakingBalanceViewModel?

    func reload(with viewModel: LocalizableResource<StakingBalanceViewModel>) {
        reloadedViewModel = viewModel.value(for: Locale.current)
    }

    func didStartLoading() {}
    func didStopLoading() {}
    func applyLocalization() {}
}

private final class StakingBalanceViewModelFactorySpy: StakingBalanceViewModelFactoryProtocol {
    private(set) var receivedPriceData: PriceData?

    func buildViewModel(
        viewModelState _: StakingBalanceViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<StakingBalanceViewModel>? {
        receivedPriceData = priceData

        return LocalizableResource { _ in
            StakingBalanceViewModel(
                title: "staking balance",
                widgetViewModel: StakingBalanceWidgetViewModel(
                    title: "Staked",
                    itemViewModels: [
                        StakingBalanceWidgetItemViewModel(
                            title: "Total",
                            tokenAmountText: "10 UNIT",
                            usdAmountText: "$12.50"
                        )
                    ]
                ),
                actionsViewModel: StakingBalanceActionsWidgetViewModel(
                    bondTitle: "Bond more",
                    unbondTitle: "Unbond",
                    redeemTitle: "Redeem",
                    redeemIcon: nil,
                    redeemActionIsAvailable: true,
                    stakeMoreActionAvailable: true,
                    stakeLessActionAvailable: true
                ),
                unbondingViewModel: StakingBalanceUnbondingWidgetViewModel(
                    title: "Unbonding",
                    emptyListDescription: "No unbonding",
                    unbondings: []
                )
            )
        }
    }
}

private final class StakingBalanceViewModelStateSpy: StakingBalanceViewModelState {
    weak var stateListener: StakingBalanceModelStateListener?
    var rebondCases: [StakingRebondOption] = [.all, .customAmount]
    var bondMoreFlow: StakingBondMoreFlow? = .relaychain
    var unbondFlow: StakingUnbondSetupFlow? = .relaychain
    var revokeFlow: StakingRedeemConfirmationFlow? = .relaychain
    var validatorsShouldPass = true
    private(set) var decidedRebondOption: StakingRebondOption?

    func setStateListener(_ stateListener: StakingBalanceModelStateListener?) {
        self.stateListener = stateListener
    }

    func stakeMoreValidators(using _: Locale) -> [DataValidating] {
        validators()
    }

    func stakeLessValidators(using _: Locale) -> [DataValidating] {
        validators()
    }

    func revokeValidators(using _: Locale) -> [DataValidating] {
        validators()
    }

    func unbondingMoreValidators(using _: Locale) -> [DataValidating] {
        validators()
    }

    func decideRebondFlow(option: StakingRebondOption) {
        decidedRebondOption = option
    }

    func notifyChange() {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    private func validators() -> [DataValidating] {
        validatorsShouldPass ? [SucceedDataValidating()] : [FailingDataValidating()]
    }
}

private final class FailingDataValidating: DataValidating {
    func validate(notifying _: DataValidatingDelegate) -> DataValidationProblem? {
        .error
    }
}

private final class StakingBalanceWireframeSpy: StakingBalanceWireframeProtocol {
    private(set) var didShowBondMore = 0
    private(set) var didShowUnbond = 0
    private(set) var didShowRedeem = 0
    private(set) var didShowRebondSetup = 0
    private(set) var didShowRebondConfirm = 0
    private(set) weak var cancelledView: ControllerBackedProtocol?
    private(set) var presentedRebondViewModel: SheetAlertPresentableViewModel?

    func showBondMore(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        flow _: StakingBondMoreFlow
    ) {
        didShowBondMore += 1
    }

    func showUnbond(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        flow _: StakingUnbondSetupFlow
    ) {
        didShowUnbond += 1
    }

    func showRedeem(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        flow _: StakingRedeemConfirmationFlow
    ) {
        didShowRedeem += 1
    }

    func showRebondSetup(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        didShowRebondSetup += 1
    }

    func showRebondConfirm(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        flow _: StakingRebondConfirmationFlow
    ) {
        didShowRebondConfirm += 1
    }

    func cancel(from view: ControllerBackedProtocol?) {
        cancelledView = view
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        presentedRebondViewModel = viewModel
    }

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}
