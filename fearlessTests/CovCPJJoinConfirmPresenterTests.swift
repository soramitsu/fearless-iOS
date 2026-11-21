import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPJJoinConfirmViewDouble: StakingPoolJoinConfirmViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var loadableContentView: UIView { controller.view }
    var shouldDisableInteractionWhenLoading: Bool { true }

    private(set) var feeViewModels: [BalanceViewModelProtocol?] = []
    private(set) var confirmViewModels: [StakingPoolJoinConfirmViewModel] = []
    private(set) var events: [String] = []

    func didReceive(feeViewModel: BalanceViewModelProtocol?) { feeViewModels.append(feeViewModel) }
    func didReceive(confirmViewModel: StakingPoolJoinConfirmViewModel) { confirmViewModels.append(confirmViewModel) }
    func didStartLoading() { events.append("start") }
    func didStopLoading() { events.append("stop") }
}

final class CovCPJJoinConfirmInteractorDouble: StakingPoolJoinConfirmInteractorInput {
    private(set) weak var output: StakingPoolJoinConfirmInteractorOutput?
    private(set) var estimateCount = 0
    private(set) var submitCount = 0
    private(set) var nominationRequests: [AccountId] = []

    func setup(with output: StakingPoolJoinConfirmInteractorOutput) { self.output = output }
    func estimateFee() { estimateCount += 1 }
    func submit() { submitCount += 1 }
    func fetchPoolNomination(poolStashAccountId: AccountId) { nominationRequests.append(poolStashAccountId) }
}

final class CovCPJJoinConfirmRouterDouble: CovCPJPresentableRecorder, StakingPoolJoinConfirmRouterInput {
    private(set) var finishCount = 0
    private(set) var completionTitles: [String] = []

    func finish(view _: ControllerBackedProtocol?) { finishCount += 1 }
    func complete(on _: ControllerBackedProtocol?, title: String) { completionTitles.append(title) }
}

final class CovCPJJoinConfirmPresenterTests: XCTestCase {
    private var view: CovCPJJoinConfirmViewDouble!
    private var interactor: CovCPJJoinConfirmInteractorDouble!
    private var router: CovCPJJoinConfirmRouterDouble!
    private var logger: CovCPJLoggerDouble!
    private var authorizer: CovCPJAuthorizerDouble!
    private var wallet: fearless.MetaAccountModel!

    override func setUp() {
        super.setUp()
        view = CovCPJJoinConfirmViewDouble()
        interactor = CovCPJJoinConfirmInteractorDouble()
        router = CovCPJJoinConfirmRouterDouble()
        logger = CovCPJLoggerDouble()
        authorizer = CovCPJAuthorizerDouble()
        wallet = CovCPJFixtures.wallet()
    }

    override func tearDown() {
        view = nil
        interactor = nil
        router = nil
        logger = nil
        authorizer = nil
        wallet = nil
        super.tearDown()
    }

    private func makePresenter(poolId: String = "5") throws -> StakingPoolJoinConfirmPresenter {
        let chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        return StakingPoolJoinConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: try CovCPJFixtures.localizationManager(),
            viewModelFactory: StakingPoolJoinConfirmViewModelFactory(
                chainAsset: chainAsset,
                assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
            ),
            inputAmount: 4,
            pool: CovCPJFixtures.pool(id: poolId, name: "Alpha", points: 100, members: 3),
            wallet: wallet,
            chainAsset: chainAsset,
            balanceViewModelFactory: CovCPJFixtures.balanceFactory(chainAsset: chainAsset, wallet: wallet),
            logger: logger,
            submissionAuthorizer: authorizer
        )
    }

    func testDidLoadProvidesViewModelAndRequestsFee() throws {
        let presenter = try makePresenter()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(interactor.estimateCount, 1)
        let viewModel = try XCTUnwrap(view.confirmViewModels.first)
        XCTAssertEqual(viewModel.selectedPoolName, "Alpha")
        XCTAssertEqual(viewModel.accountNameString, wallet.name)
        XCTAssertFalse(viewModel.poolHasNoValidators)
        XCTAssertEqual(view.feeViewModels.count, 1)
        XCTAssertNil(view.feeViewModels.first ?? nil)
    }

    func testFeeResultUpdatesFeeOrLogs() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(20_000_000_000))))
        let fee = try XCTUnwrap(view.feeViewModels.last ?? nil)
        XCTAssertTrue(fee.amount.contains("2"))

        presenter.didReceiveFee(result: .failure(CovCPJTestError.failed))
        XCTAssertEqual(view.feeViewModels.count, 2)
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testConfirmRequiresAuthorization() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        authorizer.authorized = false
        presenter.didTapConfirmButton()
        XCTAssertEqual(interactor.submitCount, 0)

        authorizer.authorized = true
        presenter.didTapConfirmButton()
        XCTAssertEqual(interactor.submitCount, 1)
        XCTAssertEqual(view.events, ["start"])
    }

    func testBackDismisses() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.didTapBackButton()

        XCTAssertEqual(router.dismissCount, 1)
    }

    func testExtrinsicSuccessCompletesWithSubmittedTitle() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.didReceive(extrinsicResult: .success("0x01"))

        XCTAssertEqual(view.events, ["stop"])
        XCTAssertEqual(
            router.completionTitles,
            [R.string.localizable.commonTransactionSubmitted(preferredLanguages: CovCPJFixtures.languages)]
        )
    }

    func testExtrinsicFailurePresentsErrorOrGenericFailure() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.didReceive(extrinsicResult: .failure(CovCPJTestError.failed))
        XCTAssertEqual(router.extrinsicFailedCount, 1)

        router.presentErrorResult = true
        presenter.didReceive(extrinsicResult: .failure(CovCPJTestError.failed))
        XCTAssertEqual(router.extrinsicFailedCount, 1)
        XCTAssertEqual(router.presentedErrors.count, 2)
        XCTAssertTrue(router.completionTitles.isEmpty)
    }

    func testPalletIdDerivesPoolStashAccount() throws {
        let presenter = try makePresenter(poolId: "5")
        presenter.didLoad(view: view)
        let palletId = Data("py/nopls".utf8)

        presenter.didReceive(palletIdResult: .success(palletId))

        let accountId = try XCTUnwrap(interactor.nominationRequests.first)
        var poolId = UInt(5)
        let poolIdData = Data(bytes: &poolId, count: MemoryLayout<UInt>.size)
        let expected = (Data("modl".utf8) + palletId + Data([0]) + poolIdData + Data(repeating: 0, count: 32)).prefix(32)
        XCTAssertEqual(accountId.count, 32)
        XCTAssertEqual(Data(accountId), Data(expected))
    }

    func testPalletIdFailureOrInvalidPoolIdSkipsNominationFetch() throws {
        let presenter = try makePresenter(poolId: "not-a-number")
        presenter.didLoad(view: view)

        presenter.didReceive(palletIdResult: .failure(CovCPJTestError.failed))
        XCTAssertEqual(logger.errors.count, 1)

        presenter.didReceive(palletIdResult: .success(Data("py/nopls".utf8)))
        XCTAssertTrue(interactor.nominationRequests.isEmpty)
    }

    func testNominationUpdatesValidatorsHint() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.didReceive(nomination: nil)
        XCTAssertEqual(view.confirmViewModels.last?.poolHasNoValidators, true)

        presenter.didReceive(nomination: try CovCPJFixtures.nomination(targetCount: 3))
        XCTAssertEqual(view.confirmViewModels.last?.poolHasNoValidators, false)

        presenter.didReceive(error: CovCPJTestError.failed)
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testApplyLocalizationDoesNotReprovide() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)
        let count = view.confirmViewModels.count

        presenter.applyLocalization()

        XCTAssertEqual(view.confirmViewModels.count, count)
    }
}
