import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPJRolesOutputDouble: PoolRolesConfirmViewOutput {
    private(set) var loadedView: PoolRolesConfirmViewInput?
    private(set) var confirmTaps = 0
    private(set) var backTaps = 0

    func didLoad(view: PoolRolesConfirmViewInput) { loadedView = view }
    func didTapConfirmButton() { confirmTaps += 1 }
    func didTapBackButton() { backTaps += 1 }
}

final class CovCPJRolesViewDouble: PoolRolesConfirmViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var loadableContentView: UIView { controller.view }
    var shouldDisableInteractionWhenLoading: Bool { true }

    private(set) var feeViewModels: [BalanceViewModelProtocol?] = []
    private(set) var viewModels: [PoolRolesConfirmViewModel] = []
    private(set) var events: [String] = []

    func didReceive(feeViewModel: BalanceViewModelProtocol?) { feeViewModels.append(feeViewModel) }
    func didReceive(viewModel: PoolRolesConfirmViewModel) { viewModels.append(viewModel) }
    func didStartLoading() { events.append("start") }
    func didStopLoading() { events.append("stop") }
}

final class CovCPJRolesInteractorDouble: PoolRolesConfirmInteractorInput {
    private(set) weak var output: PoolRolesConfirmInteractorOutput?
    private(set) var estimateCount = 0
    private(set) var submitCount = 0

    func setup(with output: PoolRolesConfirmInteractorOutput) { self.output = output }
    func estimateFee() { estimateCount += 1 }
    func submit() { submitCount += 1 }
}

final class CovCPJRolesRouterDouble: CovCPJPresentableRecorder, PoolRolesConfirmRouterInput {
    private(set) var finishCount = 0
    private(set) var completionTitles: [String] = []

    func finish(view _: ControllerBackedProtocol?) { finishCount += 1 }
    func complete(on _: ControllerBackedProtocol?, title: String) { completionTitles.append(title) }
}

final class CovCPJPoolRolesConfirmViewTests: XCTestCase {
    private let languages = CovCPJFixtures.languages

    private func makeLayout() -> PoolRolesConfirmViewLayout {
        let view = PoolRolesConfirmViewLayout()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.locale = CovCPJFixtures.locale
        view.layoutIfNeeded()
        return view
    }

    private func viewModel() -> PoolRolesConfirmViewModel {
        PoolRolesConfirmViewModel(
            rootViewModel: TitleMultiValueViewModel(title: "Root wallet", subtitle: "5Root"),
            nominatorViewModel: TitleMultiValueViewModel(title: "5Nominator", subtitle: nil),
            bouncerViewModel: TitleMultiValueViewModel(title: nil, subtitle: nil)
        )
    }

    func testLayoutLocalizesTitles() {
        let view = makeLayout()

        XCTAssertEqual(view.titleLabel.text, R.string.localizable.poolUpdateRolesTitle(preferredLanguages: languages))
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.commonConfirm(preferredLanguages: languages))
        XCTAssertEqual(view.rootView.titleLabel.text, R.string.localizable.poolStakingRoot(preferredLanguages: languages))
        XCTAssertEqual(
            view.nominatorView.titleLabel.text,
            R.string.localizable.poolStakingNominator(preferredLanguages: languages)
        )
        XCTAssertEqual(view.bouncerView.titleLabel.text, R.string.localizable.poolStakingBouncer(preferredLanguages: languages))
        XCTAssertEqual(view.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: languages))
        XCTAssertEqual(
            view.confirmButton.imageWithTitleView?.title,
            R.string.localizable.commonConfirm(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.hintView.detailsLabel.text,
            R.string.localizable.poolUpdateRolesWarning(preferredLanguages: languages)
        )
        XCTAssertEqual(view.multiViews.count, 3)
        XCTAssertTrue(view.multiViews.allSatisfy { $0.borderView.isHidden })
        XCTAssertTrue(view.multiViews.allSatisfy { $0.valueTop.numberOfLines == 2 })
    }

    func testBindViewModelAndFee() {
        let view = makeLayout()

        view.bind(viewModel: viewModel())
        view.bind(feeViewModel: BalanceViewModel(amount: "0.7 DOT", price: nil))

        XCTAssertEqual(view.rootView.valueTop.text, "Root wallet")
        XCTAssertEqual(view.rootView.valueBottom.text, "5Root")
        XCTAssertFalse(view.rootView.valueBottom.isHidden)
        XCTAssertEqual(view.nominatorView.valueTop.text, "5Nominator")
        XCTAssertTrue(view.nominatorView.valueBottom.isHidden)
        XCTAssertTrue(view.bouncerView.valueTop.isHidden)
        XCTAssertEqual(view.feeView.tokenLabel.text, "0.7 DOT")
    }

    func testFactoryResolvesKnownAccountsByName() throws {
        let chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        let request = chainAsset.chain.accountRequest()
        let rootWallet = CovCPJFixtures.wallet()
        let outsider = CovCPJFixtures.wallet()
        let rootResponse = try XCTUnwrap(rootWallet.fetch(for: request))
        let outsiderResponse = try XCTUnwrap(outsider.fetch(for: request))
        let roles = CovCPJFixtures.roles(root: rootResponse.accountId, nominator: outsiderResponse.accountId, bouncer: nil)
        let factory = PoolRolesConfirmViewModelFactory(chainAsset: chainAsset)

        let viewModel = factory.buildViewModel(roles: roles, accounts: [rootWallet])

        XCTAssertEqual(viewModel.rootViewModel.title, rootWallet.name)
        XCTAssertEqual(viewModel.rootViewModel.subtitle, rootResponse.toAddress())
        XCTAssertEqual(viewModel.nominatorViewModel.title, outsiderResponse.toAddress())
        XCTAssertNil(viewModel.nominatorViewModel.subtitle)
        XCTAssertNil(viewModel.bouncerViewModel.title)
        XCTAssertNil(viewModel.bouncerViewModel.subtitle)

        let unknown = factory.buildViewModel(roles: roles, accounts: nil)
        XCTAssertEqual(unknown.rootViewModel.title, rootResponse.toAddress())
        XCTAssertNil(unknown.rootViewModel.subtitle)
    }

    func testControllerLoadsBindsAndForwardsActions() throws {
        let output = CovCPJRolesOutputDouble()
        let controller = PoolRolesConfirmViewController(
            output: output,
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        let window = CovCPJFixtures.host(controller)

        controller.didReceive(viewModel: viewModel())
        controller.didReceive(feeViewModel: BalanceViewModel(amount: "0.9 DOT", price: "$4"))
        controller.applyLocalization()
        controller.rootView.confirmButton.sendActions(for: .touchUpInside)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(output.loadedView === controller)
        XCTAssertEqual(output.confirmTaps, 1)
        XCTAssertEqual(output.backTaps, 1)
        XCTAssertEqual(controller.rootView.rootView.valueTop.text, "Root wallet")
        XCTAssertEqual(controller.rootView.feeView.fiatLabel?.text, "$4")
        XCTAssertEqual(
            controller.rootView.titleLabel.text,
            R.string.localizable.poolUpdateRolesTitle(preferredLanguages: controller.selectedLocale.rLanguages)
        )
        window.isHidden = true
    }
}

final class CovCPJPoolRolesConfirmPresenterTests: XCTestCase {
    private var view: CovCPJRolesViewDouble!
    private var interactor: CovCPJRolesInteractorDouble!
    private var router: CovCPJRolesRouterDouble!
    private var logger: CovCPJLoggerDouble!
    private var authorizer: CovCPJAuthorizerDouble!
    private var wallet: fearless.MetaAccountModel!
    private var chainAsset: ChainAsset!
    private var presenter: PoolRolesConfirmPresenter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        view = CovCPJRolesViewDouble()
        interactor = CovCPJRolesInteractorDouble()
        router = CovCPJRolesRouterDouble()
        logger = CovCPJLoggerDouble()
        authorizer = CovCPJAuthorizerDouble()
        wallet = CovCPJFixtures.wallet()
        chainAsset = CovCPJFixtures.chainAsset(precision: 10)

        let rootId = try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId)
        presenter = PoolRolesConfirmPresenter(
            interactor: interactor,
            router: router,
            balanceViewModelFactory: CovCPJFixtures.balanceFactory(chainAsset: chainAsset, wallet: wallet),
            viewModelFactory: PoolRolesConfirmViewModelFactory(chainAsset: chainAsset),
            localizationManager: try CovCPJFixtures.localizationManager(),
            roles: CovCPJFixtures.roles(root: rootId, nominator: rootId, bouncer: rootId),
            chainAsset: chainAsset,
            wallet: wallet,
            logger: logger,
            submissionAuthorizer: authorizer
        )
    }

    override func tearDown() {
        presenter = nil
        view = nil
        interactor = nil
        router = nil
        logger = nil
        authorizer = nil
        wallet = nil
        chainAsset = nil
        super.tearDown()
    }

    func testDidLoadProvidesAddressesAndRequestsFee() throws {
        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(interactor.estimateCount, 1)
        let address = try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress())
        XCTAssertEqual(view.viewModels.first?.rootViewModel.title, address)
        XCTAssertNil(view.viewModels.first?.rootViewModel.subtitle)
    }

    func testAccountsReplaceAddressesWithNames() {
        presenter.didLoad(view: view)

        presenter.didReceive(accounts: [wallet])

        XCTAssertEqual(view.viewModels.count, 2)
        XCTAssertEqual(view.viewModels.last?.rootViewModel.title, wallet.name)
        XCTAssertEqual(view.viewModels.last?.nominatorViewModel.title, wallet.name)
        XCTAssertEqual(view.viewModels.last?.bouncerViewModel.title, wallet.name)

        presenter.didReceive(error: CovCPJTestError.failed)
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testFeeResultProvidesFeeOrLogs() throws {
        presenter.didLoad(view: view)

        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(30_000_000_000))))
        let fee = try XCTUnwrap(view.feeViewModels.last ?? nil)
        XCTAssertTrue(fee.amount.contains("3"))

        presenter.didReceiveFee(result: .failure(CovCPJTestError.failed))
        XCTAssertEqual(view.feeViewModels.count, 1)
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testConfirmAndBackActions() {
        presenter.didLoad(view: view)

        authorizer.authorized = false
        presenter.didTapConfirmButton()
        XCTAssertEqual(interactor.submitCount, 0)

        authorizer.authorized = true
        presenter.didTapConfirmButton()
        XCTAssertEqual(interactor.submitCount, 1)
        XCTAssertEqual(view.events, ["start"])

        presenter.didTapBackButton()
        XCTAssertEqual(router.dismissCount, 1)
    }

    func testExtrinsicSuccessFinishesAndCompletes() {
        presenter.didLoad(view: view)

        presenter.didReceive(extrinsicResult: .success("0x02"))

        XCTAssertEqual(view.events, ["stop"])
        XCTAssertEqual(router.finishCount, 1)
        XCTAssertEqual(
            router.completionTitles,
            [R.string.localizable.commonTransactionSubmitted(preferredLanguages: CovCPJFixtures.languages)]
        )
    }

    func testExtrinsicFailurePresentsErrors() {
        presenter.didLoad(view: view)

        presenter.didReceive(extrinsicResult: .failure(CovCPJTestError.failed))
        XCTAssertEqual(router.extrinsicFailedCount, 1)

        router.presentErrorResult = true
        presenter.didReceive(extrinsicResult: .failure(CovCPJTestError.failed))
        XCTAssertEqual(router.extrinsicFailedCount, 1)
        XCTAssertEqual(router.presentedErrors.count, 2)
        XCTAssertEqual(router.finishCount, 0)

        presenter.applyLocalization()
        XCTAssertEqual(view.viewModels.count, 1)
    }
}
