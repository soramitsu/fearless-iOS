import XCTest
import SSFModels
import SoraFoundation
import BigInt
import SSFUtils
@testable import fearless

enum CovCABCACError: Error {
    case failed
}

final class CovCABCACView: UIViewController, ControllerAccountConfirmationViewProtocol {
    private(set) var reloaded: [LocalizableResource<ControllerAccountConfirmationVM>] = []
    private(set) var fees: [LocalizableResource<BalanceViewModelProtocol>?] = []
    private(set) var startLoadingCalls = 0
    private(set) var stopLoadingCalls = 0
    private(set) var presentedControllers: [UIViewController] = []

    func reload(with viewModel: LocalizableResource<ControllerAccountConfirmationVM>) { reloaded.append(viewModel) }
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) { fees.append(viewModel) }
    func applyLocalization() {}
    func didStartLoading() { startLoadingCalls += 1 }
    func didStopLoading() { stopLoadingCalls += 1 }

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }
}

final class CovCABCACWireframe: ControllerAccountConfirmationWireframeProtocol {
    private(set) var completeCalls = 0
    private(set) var closeCalls = 0
    private(set) var extrinsicFailedCalls = 0

    func complete(from _: ControllerAccountConfirmationViewProtocol?) { completeCalls += 1 }
    func close(view _: ControllerBackedProtocol?) { closeCalls += 1 }
    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) { extrinsicFailedCalls += 1 }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }
}

final class CovCABCACInteractor: ControllerAccountConfirmationInteractorInputProtocol {
    private(set) var setupCalls = 0
    private(set) var confirmCalls = 0
    private(set) var stashAddresses: [AccountAddress] = []
    private(set) var estimateFeeCalls = 0

    func setup() { setupCalls += 1 }
    func confirm() { confirmCalls += 1 }
    func fetchStashAccountItem(for address: AccountAddress) { stashAddresses.append(address) }
    func estimateFee() { estimateFeeCalls += 1 }
}

final class CovCABCACAuthorizer: SubmissionAuthorizing {
    var authorized = true
    private(set) var requests = 0

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        requests += 1
        completion(authorized)
    }
}

final class CovCABCACPresenterDouble: ControllerAccountConfirmationPresenterProtocol {
    private(set) var setupCalls = 0
    private(set) var stashCalls = 0
    private(set) var controllerCalls = 0
    private(set) var confirmCalls = 0

    func setup() { setupCalls += 1 }
    func handleStashAction() { stashCalls += 1 }
    func handleControllerAction() { controllerCalls += 1 }
    func confirm() { confirmCalls += 1 }
}

final class CovCABControllerAccountConfirmationPresenterTests: XCTestCase {
    private let languages = ["en"]
    private var view: CovCABCACView!
    private var wireframe: CovCABCACWireframe!
    private var interactor: CovCABCACInteractor!
    private var authorizer: CovCABCACAuthorizer!
    private var presenter: ControllerAccountConfirmationPresenter!
    private var stash: fearless.ChainAccountResponse!
    private var controllerAccount: fearless.ChainAccountResponse!

    override func setUp() {
        super.setUp()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        let wallet = AccountGenerator.generateMetaAccount()
        stash = wallet.fetch(for: chain.accountRequest())
        controllerAccount = AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest())

        view = CovCABCACView()
        view.localizationManager = LocalizationManager(localization: "en")
        wireframe = CovCABCACWireframe()
        interactor = CovCABCACInteractor()
        authorizer = CovCABCACAuthorizer()
        let validating = StakingDataValidatingFactory(presentable: wireframe)
        validating.view = view

        presenter = ControllerAccountConfirmationPresenter(
            controllerAccountItem: controllerAccount,
            chain: chain,
            asset: asset,
            selectedAccount: wallet,
            iconGenerator: UniversalIconGenerator(),
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet),
            dataValidatingFactory: validating,
            logger: Logger.shared,
            submissionAuthorizer: authorizer
        )
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
    }

    override func tearDown() {
        presenter = nil
        authorizer = nil
        interactor = nil
        wireframe = nil
        view = nil
        stash = nil
        controllerAccount = nil
        super.tearDown()
    }

    private func fundStash() {
        let data = AccountData(free: BigUInt(100_000_000_000), reserved: 0, frozen: 0, flags: 0)
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(nonce: 0, consumers: 0, providers: 0, data: data)))
    }

    func testSetupProvidesEmptyFeeAndStartsInteractor() {
        presenter.setup()

        XCTAssertEqual(view.fees.count, 1)
        XCTAssertNil(view.fees.first ?? nil)
        XCTAssertEqual(interactor.setupCalls, 1)
    }

    func testStashItemResults() {
        presenter.didReceiveStashItem(result: .success(StashItem(stash: "stash-address", controller: "ctrl")))
        XCTAssertEqual(interactor.stashAddresses, ["stash-address"])

        presenter.didReceiveStashItem(result: .success(nil))
        XCTAssertEqual(wireframe.closeCalls, 1)

        presenter.didReceiveStashItem(result: .failure(CovCABCACError.failed))
        XCTAssertEqual(interactor.stashAddresses.count, 1)
        XCTAssertEqual(wireframe.closeCalls, 1)
    }

    func testStashAccountReloadsAccountViewModels() throws {
        presenter.didReceiveStashAccount(result: .success(nil))
        presenter.didReceiveStashAccount(result: .failure(CovCABCACError.failed))
        XCTAssertTrue(view.reloaded.isEmpty)

        presenter.didReceiveStashAccount(result: .success(stash))

        let viewModel = try XCTUnwrap(view.reloaded.last).value(for: Locale(identifier: "en"))
        XCTAssertEqual(viewModel.stashViewModel.title, R.string.localizable.stackingStashAccount(preferredLanguages: languages))
        XCTAssertEqual(viewModel.stashViewModel.name, stash.name)
        XCTAssertEqual(viewModel.stashViewModel.address, stash.toAddress())
        XCTAssertNotNil(viewModel.stashViewModel.icon)
        XCTAssertEqual(
            viewModel.controllerViewModel.title,
            R.string.localizable.stakingControllerAccountTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(viewModel.controllerViewModel.name, controllerAccount.name)
    }

    func testFeeResults() {
        presenter.didReceiveFee(result: .failure(CovCABCACError.failed))
        XCTAssertTrue(view.fees.isEmpty)

        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
        XCTAssertEqual(view.fees.count, 1)
        XCTAssertNotNil(view.fees.first ?? nil)
    }

    func testAccountActionsShowOptions() {
        presenter.handleStashAction()
        XCTAssertTrue(view.presentedControllers.isEmpty)

        presenter.handleControllerAction()
        presenter.didReceiveStashAccount(result: .success(stash))
        presenter.handleStashAction()

        XCTAssertEqual(view.presentedControllers.count, 2)
        XCTAssertTrue(view.presentedControllers.allSatisfy { $0 is UIAlertController })
    }

    func testConfirmWithoutFeeRequestsEstimate() {
        presenter.confirm()

        XCTAssertEqual(interactor.estimateFeeCalls, 1)
        XCTAssertEqual(authorizer.requests, 0)
        XCTAssertTrue(view.presentedControllers.last is SheetAletViewController)
    }

    func testConfirmWithoutBalanceIsBlocked() {
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
        presenter.didReceiveAccountInfo(result: .success(nil))
        presenter.didReceiveAccountInfo(result: .failure(CovCABCACError.failed))

        presenter.confirm()

        XCTAssertEqual(authorizer.requests, 0)
        XCTAssertEqual(interactor.estimateFeeCalls, 0)
    }

    func testConfirmAuthorizedSubmits() {
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
        fundStash()
        presenter.didReceiveStakingLedger(result: .success(nil))
        presenter.didReceiveStakingLedger(result: .failure(CovCABCACError.failed))

        presenter.confirm()

        XCTAssertEqual(authorizer.requests, 1)
        XCTAssertEqual(view.startLoadingCalls, 1)
        XCTAssertEqual(interactor.confirmCalls, 1)
    }

    func testConfirmNotAuthorizedDoesNotSubmit() {
        authorizer.authorized = false
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
        fundStash()

        presenter.confirm()

        XCTAssertEqual(authorizer.requests, 1)
        XCTAssertEqual(interactor.confirmCalls, 0)
        XCTAssertEqual(view.startLoadingCalls, 0)
    }

    func testConfirmBlockedByExistingLedger() throws {
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
        fundStash()
        let payload: [String: Any] = [
            "stash": Data(repeating: 6, count: 32).toHex(includePrefix: true),
            "total": "1",
            "active": "1",
            "unlocking": [],
            "claimedRewards": []
        ]
        let ledger = try JSONDecoder().decode(StakingLedger.self, from: JSONSerialization.data(withJSONObject: payload))
        presenter.didReceiveStakingLedger(result: .success(ledger))

        presenter.confirm()

        XCTAssertEqual(authorizer.requests, 0)
        XCTAssertTrue(view.presentedControllers.last is SheetAletViewController)
    }

    func testDidConfirmedRoutesResult() {
        presenter.didConfirmed(result: .success("0xhash"))
        XCTAssertEqual(wireframe.completeCalls, 1)
        XCTAssertEqual(view.stopLoadingCalls, 1)

        presenter.didConfirmed(result: .failure(CovCABCACError.failed))
        XCTAssertEqual(wireframe.extrinsicFailedCalls, 1)
        XCTAssertEqual(view.stopLoadingCalls, 2)

        presenter.view = nil
        presenter.didConfirmed(result: .success("0xhash"))
        XCTAssertEqual(wireframe.completeCalls, 1)
    }
}

final class CovCABControllerAccountConfirmationViewTests: XCTestCase {
    func testLayoutAppliesLocaleToFooter() {
        let layout = ControllerAccountConfirmationLayout()
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        layout.locale = Locale(identifier: "ru")
        layout.locale = Locale(identifier: "en")
        layout.layoutIfNeeded()

        XCTAssertEqual(layout.networkFeeFooterView.locale.identifier, "en")
        XCTAssertEqual(
            layout.networkFeeFooterView.actionButton.imageWithTitleView?.title,
            R.string.localizable.commonConfirm(preferredLanguages: ["en"])
        )
        XCTAssertTrue(layout.stashAccountView.isDescendant(of: layout.containerView))
        XCTAssertTrue(layout.controllerAccountView.isDescendant(of: layout.containerView))
    }

    func testViewControllerLifecycleReloadAndActions() throws {
        let presenter = CovCABCACPresenterDouble()
        let controller = ControllerAccountConfirmationVC(
            presenter: presenter,
            localizationManager: LocalizationManager(localization: "en")
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        defer { window.isHidden = true }

        XCTAssertEqual(presenter.setupCalls, 1)
        XCTAssertEqual(controller.title, R.string.localizable.commonConfirmTitle(preferredLanguages: ["en"]))

        let viewModel = ControllerAccountConfirmationVM(
            stashViewModel: AccountInfoViewModel(title: "Stash", address: "a", name: "Stash name", icon: nil),
            controllerViewModel: AccountInfoViewModel(title: "Controller", address: "b", name: "Ctrl name", icon: R.image.iconWarning())
        )
        controller.reload(with: LocalizableResource { _ in viewModel })

        XCTAssertEqual(controller.rootView.stashAccountView.title, "Stash")
        XCTAssertEqual(controller.rootView.stashAccountView.subtitle, "Stash name")
        XCTAssertEqual(controller.rootView.controllerAccountView.title, "Controller")
        XCTAssertEqual(controller.rootView.controllerAccountView.subtitle, "Ctrl name")
        XCTAssertNotNil(controller.rootView.controllerAccountView.iconImage)

        controller.didReceiveFee(viewModel: LocalizableResource { _ in BalanceViewModel(amount: "0.2 DOT", price: nil) })
        XCTAssertEqual(controller.rootView.networkFeeFooterView.networkFeeView?.tokenLabel.text, "0.2 DOT")

        controller.applyLocalization()
        XCTAssertEqual(controller.rootView.networkFeeFooterView.networkFeeView?.tokenLabel.text, "0.2 DOT")

        controller.rootView.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        controller.rootView.stashAccountView.sendActions(for: .touchUpInside)
        controller.rootView.controllerAccountView.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.confirmCalls, 1)
        XCTAssertEqual(presenter.stashCalls, 1)
        XCTAssertEqual(presenter.controllerCalls, 1)

        let subviewCount = controller.view.subviews.count
        controller.didReachTransferStage(.accepted)
        controller.didBreakTransfer()
        XCTAssertEqual(controller.view.subviews.count, subviewCount)
        XCTAssertEqual(controller.selectedLocale.identifier, "en")
    }
}
