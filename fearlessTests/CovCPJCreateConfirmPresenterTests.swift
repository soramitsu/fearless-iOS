import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPJCreateConfirmViewDouble: StakingPoolCreateConfirmViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var loadableContentView: UIView { controller.view }
    var shouldDisableInteractionWhenLoading: Bool { true }

    private(set) var feeViewModels: [BalanceViewModelProtocol?] = []
    private(set) var confirmViewModels: [StakingPoolCreateConfirmViewModel] = []
    private(set) var events: [String] = []

    func didReceive(feeViewModel: BalanceViewModelProtocol?) { feeViewModels.append(feeViewModel) }
    func didReceive(confirmViewModel: StakingPoolCreateConfirmViewModel) { confirmViewModels.append(confirmViewModel) }
    func didStartLoading() { events.append("start") }
    func didStopLoading() { events.append("stop") }
}

final class CovCPJCreateConfirmInteractorDouble: StakingPoolCreateConfirmInteractorInput {
    private(set) weak var output: StakingPoolCreateConfirmInteractorOutput?
    private(set) var estimateCount = 0
    private(set) var submitCount = 0

    func setup(with output: StakingPoolCreateConfirmInteractorOutput) { self.output = output }
    func estimateFee() { estimateCount += 1 }
    func submit() { submitCount += 1 }
}

final class CovCPJCreateConfirmRouterDouble: CovCPJPresentableRecorder, StakingPoolCreateConfirmRouterInput {
    struct CovCCompletion {
        let hash: String
        let text: String
        let closure: (() -> Void)?
    }

    struct CovCValidatorsStart {
        let poolId: UInt32
        let state: InitiatedBonding
        let walletId: String
    }

    private(set) var finishCount = 0
    private(set) var completions: [CovCCompletion] = []
    private(set) var validatorStarts: [CovCValidatorsStart] = []

    func finish(view _: ControllerBackedProtocol?) { finishCount += 1 }

    func complete(
        on _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        extrinsicHash: String,
        text: String,
        closure: (() -> Void)?
    ) {
        completions.append(CovCCompletion(hash: extrinsicHash, text: text, closure: closure))
    }

    func proceedToSelectValidatorsStart(
        from _: ControllerBackedProtocol?,
        poolId: UInt32,
        state: InitiatedBonding,
        chainAsset _: ChainAsset,
        wallet: fearless.MetaAccountModel
    ) {
        validatorStarts.append(CovCValidatorsStart(poolId: poolId, state: state, walletId: wallet.metaId))
    }
}

final class CovCPJCreateConfirmPresenterTests: XCTestCase {
    private var view: CovCPJCreateConfirmViewDouble!
    private var interactor: CovCPJCreateConfirmInteractorDouble!
    private var router: CovCPJCreateConfirmRouterDouble!
    private var logger: CovCPJLoggerDouble!
    private var authorizer: CovCPJAuthorizerDouble!
    private var root: fearless.MetaAccountModel!
    private var nominator: fearless.MetaAccountModel!
    private var presenter: StakingPoolCreateConfirmPresenter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        view = CovCPJCreateConfirmViewDouble()
        interactor = CovCPJCreateConfirmInteractorDouble()
        router = CovCPJCreateConfirmRouterDouble()
        logger = CovCPJLoggerDouble()
        authorizer = CovCPJAuthorizerDouble()
        root = CovCPJFixtures.wallet()
        nominator = CovCPJFixtures.wallet()

        let chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        let createData = StakingPoolCreateData(
            poolId: 9,
            poolName: "Pool",
            amount: 10,
            root: root,
            nominator: nominator,
            bouncer: root,
            chainAsset: chainAsset
        )

        presenter = StakingPoolCreateConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: try CovCPJFixtures.localizationManager(),
            viewModelFactory: StakingPoolCreateConfirmViewModelFactory(
                chainAsset: chainAsset,
                assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
            ),
            createData: createData,
            balanceViewModelFactory: CovCPJFixtures.balanceFactory(chainAsset: chainAsset, wallet: root),
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
        root = nil
        nominator = nil
        super.tearDown()
    }

    func testDidLoadSetsUpAndProvidesConfirmViewModel() throws {
        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(interactor.estimateCount, 1)
        let viewModel = try XCTUnwrap(view.confirmViewModels.first)
        XCTAssertEqual(viewModel.rootName, root.name)
        XCTAssertEqual(viewModel.nominatorName, nominator.name)
        XCTAssertEqual(viewModel.bouncerName, root.name)
        XCTAssertEqual(viewModel.poolId, "9")
        XCTAssertTrue(viewModel.amountString.contains("10"))
        XCTAssertNil(viewModel.price)
    }

    func testFeeResultProvidesFeeViewModel() throws {
        presenter.didLoad(view: view)

        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(5_000_000_000))))
        let fee = try XCTUnwrap(view.feeViewModels.last ?? nil)
        XCTAssertTrue(fee.amount.contains("0.5"))

        presenter.didReceiveFee(result: .failure(CovCPJTestError.failed))
        XCTAssertEqual(view.feeViewModels.count, 1)
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testConfirmSubmitsOnlyWhenAuthorized() {
        presenter.didLoad(view: view)

        authorizer.authorized = false
        presenter.didTapConfirmButton()
        XCTAssertEqual(interactor.submitCount, 0)
        XCTAssertTrue(view.events.isEmpty)

        authorizer.authorized = true
        presenter.didTapConfirmButton()
        XCTAssertEqual(authorizer.requests, 2)
        XCTAssertEqual(interactor.submitCount, 1)
        XCTAssertEqual(view.events, ["start"])
    }

    func testBackDismisses() {
        presenter.didLoad(view: view)

        presenter.didTapBackButton()

        XCTAssertEqual(router.dismissCount, 1)
    }

    func testExtrinsicSuccessKeepsLoadingUntilPoolMemberArrives() throws {
        presenter.didLoad(view: view)

        presenter.didReceive(extrinsicResult: .success("0xabc"))
        XCTAssertEqual(view.events, ["stop", "start"])

        presenter.didReceive(stakingPoolMembers: .success(nil))
        XCTAssertTrue(router.completions.isEmpty)

        presenter.didReceive(stakingPoolMembers: .success(try CovCPJFixtures.poolMember(poolId: 9, points: "100")))
        XCTAssertEqual(view.events.last, "stop")

        let completion = try XCTUnwrap(router.completions.first)
        XCTAssertEqual(completion.hash, "0xabc")
        XCTAssertEqual(
            completion.text,
            R.string.localizable.alertPoolCreatedText(preferredLanguages: CovCPJFixtures.languages)
        )

        completion.closure?()
        let start = try XCTUnwrap(router.validatorStarts.first)
        XCTAssertEqual(start.poolId, 9)
        XCTAssertEqual(start.state.amount, 10)
        XCTAssertEqual(start.walletId, root.metaId)
    }

    func testPoolMemberWithoutHashDoesNotComplete() throws {
        presenter.didLoad(view: view)

        presenter.didReceive(stakingPoolMembers: .success(try CovCPJFixtures.poolMember(poolId: 9, points: "100")))

        XCTAssertEqual(view.events, ["stop"])
        XCTAssertTrue(router.completions.isEmpty)
    }

    func testPoolMemberFailurePresentsError() {
        presenter.didLoad(view: view)

        presenter.didReceive(stakingPoolMembers: .failure(CovCPJTestError.failed))

        XCTAssertEqual(router.presentedErrors.count, 1)
    }

    func testExtrinsicFailureFallsBackToGenericAlert() {
        presenter.didLoad(view: view)

        router.presentErrorResult = false
        presenter.didReceive(extrinsicResult: .failure(CovCPJTestError.failed))
        XCTAssertEqual(router.presentedErrors.count, 1)
        XCTAssertEqual(router.extrinsicFailedCount, 1)

        router.presentErrorResult = true
        presenter.didReceive(extrinsicResult: .failure(CovCPJTestError.failed))
        XCTAssertEqual(router.presentedErrors.count, 2)
        XCTAssertEqual(router.extrinsicFailedCount, 1)
        XCTAssertEqual(view.events, ["stop", "stop"])
    }

    func testApplyLocalizationReprovidesViewModels() {
        presenter.didLoad(view: view)
        let confirmCount = view.confirmViewModels.count

        presenter.applyLocalization()

        XCTAssertEqual(view.confirmViewModels.count, confirmCount + 1)
        XCTAssertEqual(view.feeViewModels.count, 1)
        XCTAssertNil(view.feeViewModels.first ?? nil)
    }
}
