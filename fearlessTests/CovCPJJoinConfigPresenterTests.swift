import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPJJoinConfigViewDouble: StakingPoolJoinConfigViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }

    private(set) var accountViewModels: [AccountViewModel] = []
    private(set) var assetViewModels: [AssetBalanceViewModelProtocol] = []
    private(set) var inputViewModels: [IAmountInputViewModel] = []
    private(set) var locales: [Locale] = []
    private(set) var feeViewModels: [BalanceViewModelProtocol?] = []

    func didReceiveAccountViewModel(_ accountViewModel: AccountViewModel) { accountViewModels.append(accountViewModel) }
    func didReceiveAssetBalanceViewModel(_ assetBalanceViewModel: AssetBalanceViewModelProtocol) {
        assetViewModels.append(assetBalanceViewModel)
    }

    func didReceiveAmountInputViewModel(_ amountInputViewModel: IAmountInputViewModel) {
        inputViewModels.append(amountInputViewModel)
    }

    func didReceive(locale: Locale) { locales.append(locale) }
    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?) { feeViewModels.append(feeViewModel) }
}

final class CovCPJJoinConfigInteractorDouble: StakingPoolJoinConfigInteractorInput {
    private(set) weak var output: StakingPoolJoinConfigInteractorOutput?
    private(set) var estimateCount = 0

    func setup(with output: StakingPoolJoinConfigInteractorOutput) { self.output = output }
    func estimateFee() { estimateCount += 1 }
}

final class CovCPJJoinConfigRouterDouble: CovCPJPresentableRecorder, StakingPoolJoinConfigRouterInput {
    private(set) var poolListAmounts: [Decimal] = []

    func presentPoolsList(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        inputAmount: Decimal
    ) {
        poolListAmounts.append(inputAmount)
    }
}

final class CovCPJJoinConfigAccountFactoryStub: AccountViewModelFactoryProtocol {
    private(set) var requestedAddresses: [String] = []

    func buildViewModel(title: String, address: String, locale _: Locale) -> AccountViewModel {
        requestedAddresses.append(address)
        return AccountViewModel(title: title, name: address, icon: nil)
    }

    func buildViewModel(title: String, address: String, name: String?, locale _: Locale) -> AccountViewModel {
        requestedAddresses.append(address)
        return AccountViewModel(title: title, name: name ?? address, icon: nil)
    }
}

final class CovCPJJoinConfigPresenterTests: XCTestCase {
    private let oneToken = BigUInt(10_000_000_000)

    private var view: CovCPJJoinConfigViewDouble!
    private var interactor: CovCPJJoinConfigInteractorDouble!
    private var router: CovCPJJoinConfigRouterDouble!
    private var logger: CovCPJLoggerDouble!
    private var accountFactory: CovCPJJoinConfigAccountFactoryStub!
    private var validationView: CovCPJValidationViewDouble!
    private var wallet: fearless.MetaAccountModel!
    private var presenter: StakingPoolJoinConfigPresenter!

    override func setUp() {
        super.setUp()
        view = CovCPJJoinConfigViewDouble()
        interactor = CovCPJJoinConfigInteractorDouble()
        router = CovCPJJoinConfigRouterDouble()
        logger = CovCPJLoggerDouble()
        accountFactory = CovCPJJoinConfigAccountFactoryStub()
        validationView = CovCPJValidationViewDouble()
        wallet = CovCPJFixtures.wallet()
    }

    override func tearDown() {
        presenter = nil
        view = nil
        interactor = nil
        router = nil
        logger = nil
        accountFactory = nil
        validationView = nil
        wallet = nil
        super.tearDown()
    }

    private func loadedPresenter(amount: Decimal?) throws -> StakingPoolJoinConfigPresenter {
        let chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        let balanceFactory = CovCPJFixtures.balanceFactory(chainAsset: chainAsset, wallet: wallet)
        let validatingFactory = StakingDataValidatingFactory(presentable: router, balanceFactory: balanceFactory)
        validatingFactory.view = validationView

        let presenter = StakingPoolJoinConfigPresenter(
            interactor: interactor,
            router: router,
            localizationManager: try CovCPJFixtures.localizationManager(),
            balanceViewModelFactory: balanceFactory,
            accountViewModelFactory: accountFactory,
            wallet: wallet,
            chainAsset: chainAsset,
            logger: logger,
            dataValidatingFactory: validatingFactory,
            amount: amount
        )
        presenter.didLoad(view: view)
        self.presenter = presenter
        return presenter
    }

    private func provideFunds(_ presenter: StakingPoolJoinConfigPresenter, balance: BigUInt, fee: BigUInt, deposit: BigUInt) {
        presenter.didReceiveAccountInfo(result: .success(CovCPJFixtures.accountInfo(free: balance)))
        presenter.didReceive(existentialDepositResult: .success(deposit))
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
    }

    func testDidLoadProvidesAllViewModelsAndRequestsFee() throws {
        let presenter = try loadedPresenter(amount: 2)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.locales.count, 1)
        XCTAssertEqual(view.accountViewModels.first?.name, wallet.name)
        XCTAssertEqual(
            view.accountViewModels.first?.title,
            R.string.localizable.poolStakingJoinTitle(preferredLanguages: CovCPJFixtures.languages)
        )
        XCTAssertEqual(accountFactory.requestedAddresses, [wallet.name])
        XCTAssertEqual(view.assetViewModels.count, 1)
        XCTAssertEqual(view.inputViewModels.first?.displayAmount, "2")
        XCTAssertEqual(interactor.estimateCount, 1)
    }

    func testAccountInfoAndFeeUpdateViewModels() throws {
        let presenter = try loadedPresenter(amount: nil)

        presenter.didReceiveAccountInfo(result: .success(CovCPJFixtures.accountInfo(free: oneToken * 42)))
        XCTAssertTrue(view.assetViewModels.last?.balance?.contains("42") ?? false)

        presenter.didReceiveAccountInfo(result: .success(nil))
        XCTAssertTrue(view.assetViewModels.last?.balance?.hasPrefix("0") ?? false)

        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: oneToken * 2)))
        let fee = try XCTUnwrap(view.feeViewModels.last ?? nil)
        XCTAssertTrue(fee.amount.contains("2"))

        presenter.didReceiveAccountInfo(result: .failure(CovCPJTestError.failed))
        presenter.didReceiveFee(result: .failure(CovCPJTestError.failed))
        presenter.didReceive(existentialDepositResult: .failure(CovCPJTestError.failed))
        XCTAssertEqual(logger.errors.count, 3)
    }

    func testPercentageNeedsFeeAndDeposit() throws {
        let presenter = try loadedPresenter(amount: nil)
        let inputs = view.inputViewModels.count

        presenter.selectAmountPercentage(0.5)

        XCTAssertEqual(view.inputViewModels.count, inputs)
        XCTAssertEqual(interactor.estimateCount, 1)
    }

    func testPercentageUsesBalanceMinusFeeAndDeposit() throws {
        let presenter = try loadedPresenter(amount: nil)
        provideFunds(presenter, balance: oneToken * 22, fee: oneToken, deposit: oneToken)

        presenter.selectAmountPercentage(0.5)

        XCTAssertEqual(view.inputViewModels.last?.displayAmount, "10")
        XCTAssertEqual(interactor.estimateCount, 2)

        let inputs = view.inputViewModels.count
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: oneToken)))
        XCTAssertEqual(view.inputViewModels.count, inputs + 1)
    }

    func testUpdateAmountAndBack() throws {
        let presenter = try loadedPresenter(amount: nil)
        let assets = view.assetViewModels.count

        presenter.updateAmount(6)
        presenter.didTapBackButton()

        XCTAssertEqual(view.assetViewModels.count, assets + 1)
        XCTAssertEqual(interactor.estimateCount, 2)
        XCTAssertEqual(router.dismissCount, 1)
    }

    func testApplyLocalizationProvidesFee() throws {
        let presenter = try loadedPresenter(amount: nil)

        presenter.applyLocalization()
        XCTAssertNil(view.feeViewModels.last ?? nil)

        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: oneToken)))
        presenter.applyLocalization()
        XCTAssertNotNil(view.feeViewModels.last ?? nil)
    }

    func testContinueWithoutFeeAsksForFeeAgain() throws {
        let presenter = try loadedPresenter(amount: 2)

        presenter.didTapContinueButton()

        XCTAssertEqual(router.feeNotReceivedCount, 1)
        XCTAssertEqual(interactor.estimateCount, 2)
        XCTAssertTrue(router.poolListAmounts.isEmpty)
    }

    func testContinueBelowMinimumBond() throws {
        let presenter = try loadedPresenter(amount: 2)
        presenter.didReceiveMinBond(nil)
        presenter.didReceiveMinBond(oneToken * 10)

        presenter.didTapContinueButton()

        XCTAssertEqual(router.amountTooLowValues.count, 1)
        XCTAssertTrue(router.poolListAmounts.isEmpty)
    }

    func testContinueAboveBalance() throws {
        let presenter = try loadedPresenter(amount: 20)
        provideFunds(presenter, balance: oneToken * 5, fee: oneToken, deposit: oneToken)

        presenter.didTapContinueButton()

        XCTAssertEqual(router.amountTooHighCount, 1)
        XCTAssertTrue(router.poolListAmounts.isEmpty)
    }

    func testContinueViolatingDepositShowsError() throws {
        let presenter = try loadedPresenter(amount: Decimal(string: "99.2"))
        provideFunds(presenter, balance: oneToken * 100, fee: oneToken / 2, deposit: oneToken)

        presenter.didTapContinueButton()

        XCTAssertEqual(router.existentialDepositErrors.count, 1)
        XCTAssertTrue(router.poolListAmounts.isEmpty)
    }

    func testContinueWithValidDataOpensPoolList() throws {
        let presenter = try loadedPresenter(amount: 2)
        provideFunds(presenter, balance: oneToken * 100, fee: oneToken, deposit: oneToken)
        presenter.didReceiveMinBond(oneToken)

        presenter.didTapContinueButton()

        XCTAssertEqual(router.poolListAmounts, [2])
        XCTAssertEqual(router.existentialDepositErrors.count, 0)
        XCTAssertEqual(router.amountTooLowValues.count, 0)
    }
}
