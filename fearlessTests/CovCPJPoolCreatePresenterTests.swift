import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPJPoolCreateViewDouble: StakingPoolCreateViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }

    private(set) var assetViewModels: [AssetBalanceViewModelProtocol] = []
    private(set) var inputViewModels: [IAmountInputViewModel] = []
    private(set) var feeViewModels: [BalanceViewModelProtocol?] = []
    private(set) var viewModels: [StakingPoolCreateViewModel] = []
    private(set) var nameViewModel: InputViewModelProtocol?

    func didReceiveAssetBalanceViewModel(_ assetBalanceViewModel: AssetBalanceViewModelProtocol) {
        assetViewModels.append(assetBalanceViewModel)
    }

    func didReceiveAmountInputViewModel(_ amountInputViewModel: IAmountInputViewModel) {
        inputViewModels.append(amountInputViewModel)
    }

    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?) {
        feeViewModels.append(feeViewModel)
    }

    func didReceiveViewModel(_ viewModel: StakingPoolCreateViewModel) {
        viewModels.append(viewModel)
    }

    func didReceive(nameViewModel: InputViewModelProtocol) {
        self.nameViewModel = nameViewModel
    }
}

final class CovCPJPoolCreateInteractorDouble: StakingPoolCreateInteractorInput {
    struct CovCFeeRequest {
        let amount: BigUInt?
        let poolName: String
        let poolId: UInt32?
    }

    private(set) weak var output: StakingPoolCreateInteractorOutput?
    private(set) var feeRequests: [CovCFeeRequest] = []

    func setup(with output: StakingPoolCreateInteractorOutput) {
        self.output = output
    }

    func estimateFee(amount: BigUInt?, poolName: String, poolId: UInt32?) {
        feeRequests.append(CovCFeeRequest(amount: amount, poolName: poolName, poolId: poolId))
    }
}

final class CovCPJPoolCreateRouterDouble: CovCPJPresentableRecorder, StakingPoolCreateRouterInput {
    private(set) var walletTags: [Int] = []
    private(set) var walletOutputs: [WalletsManagmentModuleOutput?] = []
    private(set) var confirmedData: [StakingPoolCreateData] = []

    func showWalletManagment(
        contextTag: Int,
        from _: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    ) {
        walletTags.append(contextTag)
        walletOutputs.append(moduleOutput)
    }

    func showConfirm(from _: ControllerBackedProtocol?, with createData: StakingPoolCreateData) {
        confirmedData.append(createData)
    }
}

final class CovCPJPoolCreatePresenterTests: XCTestCase {
    private let oneToken = BigUInt(10_000_000_000)

    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var view: CovCPJPoolCreateViewDouble!
    private var interactor: CovCPJPoolCreateInteractorDouble!
    private var router: CovCPJPoolCreateRouterDouble!
    private var logger: CovCPJLoggerDouble!
    private var validationView: CovCPJValidationViewDouble!
    private var presenter: StakingPoolCreatePresenter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        wallet = CovCPJFixtures.wallet()
        view = CovCPJPoolCreateViewDouble()
        interactor = CovCPJPoolCreateInteractorDouble()
        router = CovCPJPoolCreateRouterDouble()
        logger = CovCPJLoggerDouble()
        validationView = CovCPJValidationViewDouble()
    }

    override func tearDown() {
        presenter = nil
        view = nil
        interactor = nil
        router = nil
        logger = nil
        validationView = nil
        chainAsset = nil
        wallet = nil
        super.tearDown()
    }

    private func makePresenter(amount: Decimal?) throws -> StakingPoolCreatePresenter {
        let balanceFactory = CovCPJFixtures.balanceFactory(chainAsset: chainAsset, wallet: wallet)
        let validatingFactory = StakingDataValidatingFactory(presentable: router, balanceFactory: balanceFactory)
        validatingFactory.view = validationView

        let presenter = StakingPoolCreatePresenter(
            interactor: interactor,
            router: router,
            localizationManager: try CovCPJFixtures.localizationManager(),
            balanceViewModelFactory: balanceFactory,
            viewModelFactory: StakingPoolCreateViewModelFactory(),
            dataValidatingFactory: validatingFactory,
            logger: logger,
            wallet: wallet,
            chainAsset: chainAsset,
            amount: amount
        )
        self.presenter = presenter
        return presenter
    }

    private func loadedPresenter(amount: Decimal?) throws -> StakingPoolCreatePresenter {
        let presenter = try makePresenter(amount: amount)
        presenter.didLoad(view: view)
        return presenter
    }

    private func typeName(_ name: String) {
        _ = view.nameViewModel?.inputHandler.didReceiveReplacement(name, for: NSRange(location: 0, length: 0))
    }

    private func provideFunds(presenter: StakingPoolCreatePresenter, balance: BigUInt, fee: BigUInt, deposit: BigUInt) {
        presenter.didReceiveAccountInfo(result: .success(CovCPJFixtures.accountInfo(free: balance)))
        presenter.didReceive(existentialDepositResult: .success(deposit))
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
    }

    // MARK: - Loading

    func testDidLoadSetsUpInteractorAndProvidesInitialState() throws {
        let presenter = try loadedPresenter(amount: 2)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(interactor.feeRequests.count, 1)
        XCTAssertEqual(interactor.feeRequests.first?.amount, oneToken * 2)
        XCTAssertEqual(interactor.feeRequests.first?.poolName, "")
        XCTAssertNil(interactor.feeRequests.first?.poolId)

        XCTAssertEqual(view.viewModels.count, 1)
        XCTAssertNil(view.viewModels.first?.poolId)
        XCTAssertEqual(view.viewModels.first?.depositor, wallet.name)
        XCTAssertEqual(view.viewModels.first?.root, wallet.name)
        XCTAssertEqual(view.inputViewModels.first?.displayAmount, "2")
        XCTAssertEqual(view.feeViewModels.count, 1)
        XCTAssertNil(view.feeViewModels.first ?? nil)
        XCTAssertNotNil(view.nameViewModel)
    }

    func testDidLoadWithoutAmountRequestsZeroFee() throws {
        _ = try loadedPresenter(amount: nil)

        XCTAssertEqual(interactor.feeRequests.first?.amount, BigUInt(0))
        XCTAssertEqual(view.inputViewModels.first?.displayAmount, "")
    }

    // MARK: - Interactor output

    func testLastPoolIdIncrementsPoolIdAndRefreshesFee() throws {
        let presenter = try loadedPresenter(amount: 1)

        presenter.didReceiveLastPoolId(5)

        XCTAssertEqual(view.viewModels.last?.poolId, 6)
        XCTAssertEqual(interactor.feeRequests.last?.poolId, 5)
    }

    func testAccountInfoProvidesBalance() throws {
        let presenter = try loadedPresenter(amount: 1)

        presenter.didReceiveAccountInfo(result: .success(CovCPJFixtures.accountInfo(free: oneToken * 100, frozen: oneToken)))
        let balance = try XCTUnwrap(view.assetViewModels.last?.balance)
        XCTAssertTrue(balance.contains("99"))
        XCTAssertEqual(view.assetViewModels.last?.symbol.uppercased(), "DOT")

        presenter.didReceiveAccountInfo(result: .success(nil))
        let zeroBalance = try XCTUnwrap(view.assetViewModels.last?.balance)
        XCTAssertTrue(zeroBalance.hasPrefix("0"))
        XCTAssertFalse(zeroBalance.contains("99"))

        let countBefore = view.assetViewModels.count
        presenter.didReceiveAccountInfo(result: .failure(CovCPJTestError.failed))
        XCTAssertEqual(view.assetViewModels.count, countBefore)
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testFeeResultUpdatesFeeViewModel() throws {
        let presenter = try loadedPresenter(amount: 1)

        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: oneToken)))

        let fee = try XCTUnwrap(view.feeViewModels.last ?? nil)
        XCTAssertTrue(fee.amount.contains("1"))
        XCTAssertNil(fee.price)

        let feeCount = view.feeViewModels.count
        presenter.didReceiveFee(result: .failure(CovCPJTestError.failed))
        XCTAssertEqual(view.feeViewModels.count, feeCount)
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testPercentageSelectionUsesBalanceMinusFeeAndDeposit() throws {
        let presenter = try loadedPresenter(amount: nil)
        provideFunds(presenter: presenter, balance: oneToken * 102, fee: oneToken, deposit: oneToken)

        presenter.selectAmountPercentage(0.5)

        XCTAssertEqual(view.inputViewModels.last?.displayAmount, "50")
        XCTAssertEqual(interactor.feeRequests.last?.amount, oneToken * 50)

        let inputCount = view.inputViewModels.count
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: oneToken)))
        XCTAssertEqual(view.inputViewModels.count, inputCount + 1)
    }

    func testUpdateAmountRefreshesAssetAndFee() throws {
        let presenter = try loadedPresenter(amount: nil)
        let assetCount = view.assetViewModels.count

        presenter.updateAmount(3)

        XCTAssertEqual(view.assetViewModels.count, assetCount + 1)
        XCTAssertEqual(interactor.feeRequests.last?.amount, oneToken * 3)

        let inputCount = view.inputViewModels.count
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: oneToken)))
        XCTAssertEqual(view.inputViewModels.count, inputCount)
    }

    func testExistentialDepositResultRefreshesFeeOrLogs() throws {
        let presenter = try loadedPresenter(amount: 1)
        let requests = interactor.feeRequests.count

        presenter.didReceive(existentialDepositResult: .success(oneToken))
        XCTAssertEqual(interactor.feeRequests.count, requests + 1)

        presenter.didReceive(existentialDepositResult: .failure(CovCPJTestError.failed))
        XCTAssertEqual(interactor.feeRequests.count, requests + 1)
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testExistingPoolMemberShowsAlertThatDismisses() throws {
        let presenter = try loadedPresenter(amount: 1)

        presenter.didReceivePoolMember(nil)
        presenter.didReceivePoolMember(try CovCPJFixtures.poolMember(poolId: 1, points: "10"))
        CovCPJFixtures.spin { !self.router.sheetViewModels.isEmpty }

        XCTAssertEqual(router.sheetViewModels.count, 1)
        let sheet = try XCTUnwrap(router.sheetViewModels.first)
        XCTAssertEqual(
            sheet.title,
            R.string.localizable.stakingPoolCreateMissingNameTitle(preferredLanguages: CovCPJFixtures.languages)
        )
        XCTAssertEqual(sheet.actions.count, 1)

        sheet.actions.first?.handler?()
        XCTAssertEqual(router.dismissCount, 1)
    }

    // MARK: - View output

    func testRoleTapsOpenWalletManagementWithContextTags() throws {
        let presenter = try loadedPresenter(amount: 1)

        presenter.nominatorDidTapped()
        presenter.bouncerDidTapped()
        presenter.rootDidTapped()

        XCTAssertEqual(router.walletTags, [0, 1, 2])
        XCTAssertTrue(router.walletOutputs.allSatisfy { $0 === presenter })
    }

    func testSelectedWalletsUpdateViewModel() throws {
        let presenter = try loadedPresenter(amount: 1)
        let nominator = CovCPJFixtures.wallet()
        let bouncer = CovCPJFixtures.wallet()
        let root = CovCPJFixtures.wallet()

        presenter.selectedWallet(nominator, for: 0)
        XCTAssertEqual(view.viewModels.last?.naminator, nominator.name)

        presenter.selectedWallet(bouncer, for: 1)
        XCTAssertEqual(view.viewModels.last?.bouncer, bouncer.name)

        presenter.selectedWallet(root, for: 2)
        XCTAssertEqual(view.viewModels.last?.root, root.name)

        let count = view.viewModels.count
        presenter.selectedWallet(root, for: 99)
        XCTAssertEqual(view.viewModels.count, count)
    }

    func testBackAndNameChangeActions() throws {
        let presenter = try loadedPresenter(amount: 1)

        presenter.backDidTapped()
        XCTAssertEqual(router.dismissCount, 1)

        typeName("Sun pool")
        presenter.nameTextFieldInputValueChanged()
        XCTAssertEqual(interactor.feeRequests.last?.poolName, "Sun pool")
    }

    func testApplyLocalizationReprovidesAmountViewModels() throws {
        let presenter = try loadedPresenter(amount: 1)
        let assets = view.assetViewModels.count
        let inputs = view.inputViewModels.count

        presenter.applyLocalization()

        XCTAssertEqual(view.assetViewModels.count, assets + 1)
        XCTAssertEqual(view.inputViewModels.count, inputs + 1)
    }
}

// MARK: - Create validation

extension CovCPJPoolCreatePresenterTests {
    func testCreateWithoutFeeReportsMissingFeeAndRefreshes() throws {
        let presenter = try loadedPresenter(amount: 1)
        let requests = interactor.feeRequests.count

        presenter.createDidTapped()

        XCTAssertEqual(router.feeNotReceivedCount, 1)
        XCTAssertEqual(interactor.feeRequests.count, requests + 1)
        XCTAssertTrue(router.confirmedData.isEmpty)
    }

    func testCreateBelowMinimumBondReportsAmountTooLow() throws {
        let presenter = try loadedPresenter(amount: 1)
        presenter.didReceiveMinBond(nil)
        presenter.didReceiveMinBond(oneToken * 10)

        presenter.createDidTapped()

        XCTAssertEqual(router.amountTooLowValues.count, 1)
        XCTAssertTrue(router.amountTooLowValues.first?.contains("10") ?? false)
        XCTAssertTrue(router.confirmedData.isEmpty)
    }

    func testCreateAboveBalanceReportsAmountTooHigh() throws {
        let presenter = try loadedPresenter(amount: 5)
        provideFunds(presenter: presenter, balance: oneToken, fee: oneToken / 10, deposit: oneToken / 10)

        presenter.createDidTapped()

        XCTAssertEqual(router.amountTooHighCount, 1)
        XCTAssertTrue(router.confirmedData.isEmpty)
    }

    func testCreateWithoutNameReportsMissingName() throws {
        let presenter = try loadedPresenter(amount: 5)
        provideFunds(presenter: presenter, balance: oneToken * 100, fee: oneToken, deposit: oneToken)

        presenter.createDidTapped()

        XCTAssertEqual(router.missingPoolNameCount, 1)
        XCTAssertTrue(router.confirmedData.isEmpty)
    }

    func testCreateViolatingDepositWarnsThenConfirms() throws {
        let presenter = try loadedPresenter(amount: Decimal(string: "99.2"))
        provideFunds(presenter: presenter, balance: oneToken * 100, fee: oneToken / 2, deposit: oneToken)
        presenter.didReceiveLastPoolId(3)
        typeName("Pool")

        presenter.createDidTapped()

        XCTAssertEqual(router.existentialDepositWarnings.count, 1)
        XCTAssertTrue(router.confirmedData.isEmpty)

        router.existentialDepositActions.first?()
        XCTAssertEqual(router.confirmedData.count, 1)
        XCTAssertEqual(router.confirmedData.first?.poolId, 4)
    }

    func testCreateWithValidDataShowsConfirm() throws {
        let presenter = try loadedPresenter(amount: 5)
        provideFunds(presenter: presenter, balance: oneToken * 100, fee: oneToken, deposit: oneToken)
        presenter.didReceiveMinBond(oneToken)
        presenter.didReceiveLastPoolId(7)
        let nominator = CovCPJFixtures.wallet()
        let bouncer = CovCPJFixtures.wallet()
        presenter.selectedWallet(nominator, for: 0)
        presenter.selectedWallet(bouncer, for: 1)
        typeName("Pool")

        presenter.createDidTapped()

        let data = try XCTUnwrap(router.confirmedData.first)
        XCTAssertEqual(data.poolId, 8)
        XCTAssertEqual(data.poolName, "Pool")
        XCTAssertEqual(data.amount, 5)
        XCTAssertEqual(data.nominator.metaId, nominator.metaId)
        XCTAssertEqual(data.bouncer.metaId, bouncer.metaId)
        XCTAssertEqual(data.chainAsset.chain.chainId, chainAsset.chain.chainId)
        XCTAssertEqual(router.amountTooLowValues.count, 0)
        XCTAssertEqual(router.existentialDepositWarnings.count, 0)
    }

    func testCreateWithValidDataButNoPoolIdDoesNothing() throws {
        let presenter = try loadedPresenter(amount: 5)
        provideFunds(presenter: presenter, balance: oneToken * 100, fee: oneToken, deposit: oneToken)
        typeName("Pool")

        presenter.createDidTapped()

        XCTAssertTrue(router.confirmedData.isEmpty)
        XCTAssertEqual(router.missingPoolNameCount, 0)
        XCTAssertEqual(router.feeNotReceivedCount, 0)
    }
}
