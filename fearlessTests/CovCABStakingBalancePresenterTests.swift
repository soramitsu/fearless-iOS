import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCABSBPWireframe: StakingBalanceWireframeProtocol {
    private(set) var bondMoreFlows: [StakingBondMoreFlow] = []
    private(set) var unbondFlows: [StakingUnbondSetupFlow] = []
    private(set) var redeemFlows: [StakingRedeemConfirmationFlow] = []
    private(set) var rebondSetupCalls = 0
    private(set) var rebondConfirmFlows: [StakingRebondConfirmationFlow] = []
    private(set) var cancelCalls = 0
    private(set) var sheetViewModels: [SheetAlertPresentableViewModel] = []

    func showBondMore(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset, wallet _: fearless.MetaAccountModel, flow: StakingBondMoreFlow) {
        bondMoreFlows.append(flow)
    }

    func showUnbond(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset, wallet _: fearless.MetaAccountModel, flow: StakingUnbondSetupFlow) {
        unbondFlows.append(flow)
    }

    func showRedeem(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        flow: StakingRedeemConfirmationFlow
    ) {
        redeemFlows.append(flow)
    }

    func showRebondSetup(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset, wallet _: fearless.MetaAccountModel) {
        rebondSetupCalls += 1
    }

    func showRebondConfirm(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        flow: StakingRebondConfirmationFlow
    ) {
        rebondConfirmFlows.append(flow)
    }

    func cancel(from _: ControllerBackedProtocol?) {
        cancelCalls += 1
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheetViewModels.append(viewModel)
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }
}

final class CovCABSBPView: UIViewController, StakingBalanceViewProtocol {
    private(set) var reloaded: [LocalizableResource<StakingBalanceViewModel>] = []
    private(set) var presentedControllers: [UIViewController] = []

    func reload(with viewModel: LocalizableResource<StakingBalanceViewModel>) {
        reloaded.append(viewModel)
    }

    func applyLocalization() {}
    func didStartLoading() {}
    func didStopLoading() {}

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }
}

final class CovCABSBPInteractor: StakingBalanceInteractorInputProtocol {
    private(set) var setupCalls = 0
    private(set) var refreshCalls = 0

    func setup() {
        setupCalls += 1
    }

    func refresh() {
        refreshCalls += 1
    }
}

final class CovCABSBPViewModelFactory: StakingBalanceViewModelFactoryProtocol {
    var result: LocalizableResource<StakingBalanceViewModel>?
    private(set) var buildCalls = 0

    func buildViewModel(viewModelState _: StakingBalanceViewModelState, priceData _: PriceData?) -> LocalizableResource<StakingBalanceViewModel>? {
        buildCalls += 1
        return result
    }
}

final class CovCABSBPTimer: CountdownTimerProtocol {
    weak var delegate: CountdownTimerDelegate?
    var state: CountdownTimerState = .stopped
    var notificationInterval: TimeInterval = 1
    var remainedInterval: TimeInterval = 0

    func start(with _: TimeInterval, runLoop _: RunLoop, mode _: RunLoop.Mode) {}
    func stop() {}
}

final class CovCABSBPPresenterDouble: StakingBalancePresenterProtocol {
    private(set) var setupCalls = 0
    private(set) var refreshCalls = 0
    private(set) var actions: [StakingBalanceAction] = []
    private(set) var unbondingMoreCalls = 0

    func setup() {
        setupCalls += 1
    }

    func handleRefresh() {
        refreshCalls += 1
    }

    func handleAction(_ action: StakingBalanceAction) {
        actions.append(action)
    }

    func handleUnbondingMoreAction() {
        unbondingMoreCalls += 1
    }
}

enum CovCABSBPFixtures {
    static func sampleViewModel(title: String?) -> StakingBalanceViewModel {
        StakingBalanceViewModel(
            title: title,
            widgetViewModel: StakingBalanceWidgetViewModel(
                title: "Widget",
                itemViewModels: [StakingBalanceWidgetItemViewModel(title: "Bonded", tokenAmountText: "7 DOT", usdAmountText: nil)]
            ),
            actionsViewModel: StakingBalanceActionsWidgetViewModel(
                bondTitle: "B",
                unbondTitle: "U",
                redeemTitle: "R",
                redeemIcon: nil,
                redeemActionIsAvailable: false,
                stakeMoreActionAvailable: true,
                stakeLessActionAvailable: true
            ),
            unbondingViewModel: StakingBalanceUnbondingWidgetViewModel(
                title: "Unbondings",
                emptyListDescription: "Empty",
                unbondings: []
            )
        )
    }

    static func ledger() throws -> StakingLedger {
        let payload: [String: Any] = [
            "stash": Data(repeating: 2, count: 32).toHex(includePrefix: true),
            "total": "100",
            "active": "100",
            "unlocking": [["value": "1", "era": "1"]],
            "claimedRewards": []
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        return try JSONDecoder().decode(StakingLedger.self, from: data)
    }
}

final class CovCABStakingBalancePresenterTests: XCTestCase {
    private let languages = ["en"]
    private var wireframe: CovCABSBPWireframe!
    private var view: CovCABSBPView!
    private var interactor: CovCABSBPInteractor!
    private var factory: CovCABSBPViewModelFactory!
    private var state: StakingBalanceRelaychainViewModelState!
    private var validating: StakingDataValidatingFactory!
    private var presenter: StakingBalancePresenter!
    private var account: fearless.ChainAccountResponse!

    override func setUp() {
        super.setUp()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        let wallet = AccountGenerator.generateMetaAccount()
        account = wallet.fetch(for: chain.accountRequest())

        wireframe = CovCABSBPWireframe()
        view = CovCABSBPView()
        view.localizationManager = LocalizationManager(localization: "en")
        interactor = CovCABSBPInteractor()
        factory = CovCABSBPViewModelFactory()
        validating = StakingDataValidatingFactory(presentable: wireframe)
        state = StakingBalanceRelaychainViewModelState(countdownTimer: CovCABSBPTimer(), dataValidatingFactory: validating)
        presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: factory,
            viewModelState: state,
            dataValidatingFactory: validating,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            wallet: wallet
        )
        presenter.view = view
        validating.view = view
        state.didReceive(stashItemResult: .success(StashItem(stash: "stash-addr", controller: "ctrl-addr")))
    }

    override func tearDown() {
        presenter = nil
        state = nil
        validating = nil
        factory = nil
        interactor = nil
        view = nil
        wireframe = nil
        account = nil
        super.tearDown()
    }

    func testSetupRegistersListenerAndStartsInteractor() {
        presenter.setup()

        XCTAssertEqual(interactor.setupCalls, 1)
        XCTAssertTrue(state.stateListener === presenter)

        presenter.handleRefresh()
        XCTAssertEqual(interactor.refreshCalls, 1)
    }

    func testBondMoreRequiresStashAccount() {
        presenter.handleAction(.bondMore)

        XCTAssertTrue(wireframe.bondMoreFlows.isEmpty)
        XCTAssertEqual(view.presentedControllers.count, 1)
        XCTAssertTrue(view.presentedControllers.first is SheetAletViewController)

        state.stashAccount = account
        presenter.handleAction(.bondMore)

        XCTAssertEqual(wireframe.bondMoreFlows, [.relaychain])
        XCTAssertEqual(view.presentedControllers.count, 1)
    }

    func testUnbondRequiresControllerAndLedger() throws {
        presenter.handleAction(.unbond)
        XCTAssertTrue(wireframe.unbondFlows.isEmpty)
        XCTAssertEqual(view.presentedControllers.count, 1)

        state.controllerAccount = account
        presenter.handleAction(.unbond)
        XCTAssertTrue(wireframe.unbondFlows.isEmpty)
        XCTAssertEqual(view.presentedControllers.count, 2)

        state.stakingLedger = try CovCABSBPFixtures.ledger()
        presenter.handleAction(.unbond)
        XCTAssertEqual(wireframe.unbondFlows, [.relaychain])
    }

    func testRedeemRequiresController() {
        presenter.handleAction(.redeem)
        XCTAssertTrue(wireframe.redeemFlows.isEmpty)

        state.controllerAccount = account
        presenter.handleAction(.redeem)
        XCTAssertEqual(wireframe.redeemFlows, [.relaychain])
    }

    func testActionsIgnoredWithoutView() {
        state.stashAccount = account
        state.controllerAccount = account
        presenter.view = nil

        presenter.handleAction(.bondMore)
        presenter.handleAction(.redeem)
        presenter.handleUnbondingMoreAction()

        XCTAssertTrue(wireframe.bondMoreFlows.isEmpty)
        XCTAssertTrue(wireframe.redeemFlows.isEmpty)
        XCTAssertTrue(wireframe.sheetViewModels.isEmpty)
    }

    func testUnbondingMorePresentsRebondOptions() throws {
        presenter.handleUnbondingMoreAction()
        XCTAssertTrue(wireframe.sheetViewModels.isEmpty)
        XCTAssertEqual(view.presentedControllers.count, 1)

        state.controllerAccount = account
        presenter.setup()
        presenter.handleUnbondingMoreAction()

        let sheet = try XCTUnwrap(wireframe.sheetViewModels.last)
        XCTAssertEqual(sheet.title, R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: languages))
        XCTAssertEqual(sheet.closeAction, R.string.localizable.commonCancel(preferredLanguages: languages))
        XCTAssertNil(sheet.message)
        XCTAssertEqual(sheet.actions.map(\.title), [
            R.string.localizable.stakingRebondAll(preferredLanguages: languages),
            R.string.localizable.stakingRebondLast(preferredLanguages: languages),
            R.string.localizable.stakingRebondCustomAmount(preferredLanguages: languages)
        ])

        sheet.actions[0].handler?()
        sheet.actions[1].handler?()
        sheet.actions[2].handler?()

        XCTAssertEqual(wireframe.rebondConfirmFlows.count, 2)
        XCTAssertEqual(wireframe.rebondSetupCalls, 1)
        guard case let .relaychain(variant) = wireframe.rebondConfirmFlows[0], case .all = variant else {
            return XCTFail("expected rebond all")
        }
    }

    func testModelStateChangeReloadsOnlyWithViewModel() {
        presenter.modelStateDidChanged(viewModelState: state)
        XCTAssertEqual(factory.buildCalls, 1)
        XCTAssertTrue(view.reloaded.isEmpty)

        factory.result = LocalizableResource { _ in CovCABSBPFixtures.sampleViewModel(title: "Staking") }
        presenter.modelStateDidChanged(viewModelState: state)

        XCTAssertEqual(view.reloaded.count, 1)
        XCTAssertEqual(view.reloaded.first?.value(for: Locale(identifier: "en")).title, "Staking")
    }

    func testListenerRoutingToWireframe() {
        presenter.finishFlow()
        presenter.decideShowSetupRebondFlow()
        presenter.decideShowConfirmRebondFlow(flow: .relaychain(variant: .last))

        XCTAssertEqual(wireframe.cancelCalls, 1)
        XCTAssertEqual(wireframe.rebondSetupCalls, 1)
        XCTAssertEqual(wireframe.rebondConfirmFlows.count, 1)
    }
}

final class CovCABStakingBalanceViewControllerTests: XCTestCase {
    private var presenter: CovCABSBPPresenterDouble!
    private var controller: StakingBalanceViewController!
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        presenter = CovCABSBPPresenterDouble()
        controller = StakingBalanceViewController(
            presenter: presenter,
            localizationManager: LocalizationManager(localization: "en")
        )
        let navigation = UINavigationController(rootViewController: controller)
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        controller = nil
        presenter = nil
        super.tearDown()
    }

    func testViewDidLoadSetsTitleAndCallsSetup() {
        XCTAssertEqual(presenter.setupCalls, 1)
        XCTAssertEqual(controller.title, R.string.localizable.stakingBalanceTitle(preferredLanguages: ["en"]))
        XCTAssertTrue(controller.rootView.actionsWidget.delegate === controller)
        XCTAssertEqual(controller.selectedLocale.identifier, "en")
    }

    func testReloadBindsWidgets() {
        controller.reload(with: LocalizableResource { _ in CovCABSBPFixtures.sampleViewModel(title: "Custom title") })

        XCTAssertEqual(controller.title, "Custom title")
        XCTAssertEqual(controller.rootView.balanceWidget.balanceTitleLabel.text, "Widget")
        XCTAssertEqual(controller.rootView.unbondingWidget.titleLabel.text, "Unbondings")
        XCTAssertEqual(controller.rootView.unbondingWidget.emptyListLabel.text, "Empty")
        XCTAssertFalse(controller.rootView.unbondingWidget.moreButton.isEnabled)

        controller.reload(with: LocalizableResource { _ in CovCABSBPFixtures.sampleViewModel(title: nil) })
        XCTAssertEqual(controller.title, "Custom title")
    }

    func testControlsForwardToPresenter() {
        controller.didSelect(action: .unbond)
        controller.didSelect(action: .redeem)
        XCTAssertEqual(presenter.actions, [.unbond, .redeem])

        controller.rootView.unbondingWidget.moreButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.unbondingMoreCalls, 1)

        controller.rootView.refreshControl.sendActions(for: .valueChanged)
        XCTAssertEqual(presenter.refreshCalls, 1)
        XCTAssertFalse(controller.rootView.refreshControl.isRefreshing)
    }

    func testApplyLocalizationResetsTitle() {
        controller.title = "temp"
        controller.applyLocalization()
        XCTAssertEqual(controller.title, R.string.localizable.stakingBalanceTitle(preferredLanguages: ["en"]))
    }
}
