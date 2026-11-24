import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPMMainPresenterViewSpy: StakingPoolMainViewInput {
    let hostController = UIViewController()
    private(set) var balances: [BalanceViewModelProtocol] = []
    private(set) var chainAssets: [ChainAsset] = []
    private(set) var estimations: [StakingEstimationViewModel] = []
    private(set) var networkInfos: [[LocalizableResource<NetworkInfoContentViewModel>]] = []
    private(set) var nominatorStates: [LocalizableResource<NominationViewModelProtocol>?] = []

    var isSetup: Bool { true }
    var controller: UIViewController { hostController }

    func didReceiveBalanceViewModel(_ balanceViewModel: BalanceViewModelProtocol) { balances.append(balanceViewModel) }
    func didReceiveChainAsset(_ chainAsset: ChainAsset) { chainAssets.append(chainAsset) }
    func didReceiveEstimationViewModel(_ viewModel: StakingEstimationViewModel) { estimations.append(viewModel) }
    func didReceiveNetworkInfoViewModels(_ viewModels: [LocalizableResource<NetworkInfoContentViewModel>]) {
        networkInfos.append(viewModels)
    }

    func didReceiveNominatorStateViewModel(_ viewModel: LocalizableResource<NominationViewModelProtocol>?) {
        nominatorStates.append(viewModel)
    }
}

final class CovCPMMainPresenterInteractorSpy: StakingPoolMainInteractorInput {
    private(set) var setupCount = 0
    private(set) var updatedChainAssets: [ChainAsset] = []
    private(set) var savedChainAssets: [ChainAsset] = []
    private(set) var expansions: [Bool] = []
    private(set) var poolBalanceRequests: [AccountId] = []
    private(set) var nominationRequests: [AccountId] = []

    func setup(with _: StakingPoolMainInteractorOutput) { setupCount += 1 }
    func updateWithChainAsset(_ chainAsset: ChainAsset) { updatedChainAssets.append(chainAsset) }
    func save(chainAsset: ChainAsset) { savedChainAssets.append(chainAsset) }
    func saveNetworkInfoViewExpansion(isExpanded: Bool) { expansions.append(isExpanded) }
    func fetchPoolBalance(poolRewardAccountId: AccountId) { poolBalanceRequests.append(poolRewardAccountId) }
    func fetchPoolNomination(poolStashAccountId: AccountId) { nominationRequests.append(poolStashAccountId) }
}

final class CovCPMMainManagementInputSpy: StakingPoolManagementModuleInput {
    private(set) var statuses: [NominationViewStatus] = []
    func didChange(status: NominationViewStatus) { statuses.append(status) }
}

final class CovCPMMainPresenterRouterSpy: StakingPoolMainRouterInput {
    let managementInput = CovCPMMainManagementInputSpy()
    private(set) var assetSelectionTypes: [AssetSelectionStakingType] = []
    private(set) var rewardDetails: [(maxTitle: String, max: Decimal, avgTitle: String, avg: Decimal)] = []
    private(set) var setupAmounts: [Decimal?] = []
    private(set) var accountsSelectionCount = 0
    private(set) var managementStatuses: [NominationViewStatus?] = []
    private(set) var poolValidatorsCount = 0
    private(set) var createWalletCount = 0
    private(set) var importSources: [AccountImportSource] = []
    private(set) var backupCount = 0
    private(set) var preinstalledCount = 0

    func showChainAssetSelection(from _: StakingPoolMainViewInput?, type: AssetSelectionStakingType, delegate _: AssetSelectionDelegate) {
        assetSelectionTypes.append(type)
    }

    func showRewardDetails(
        from _: ControllerBackedProtocol?,
        maxReward: (title: String, amount: Decimal),
        avgReward: (title: String, amount: Decimal)
    ) {
        rewardDetails.append((maxReward.title, maxReward.amount, avgReward.title, avgReward.amount))
    }

    func showSetupAmount(from _: ControllerBackedProtocol?, amount: Decimal?, chainAsset _: ChainAsset, wallet _: fearless.MetaAccountModel) {
        setupAmounts.append(amount)
    }

    func showAccountsSelection(from _: ControllerBackedProtocol?, moduleOutput _: WalletsManagmentModuleOutput) {
        accountsSelectionCount += 1
    }

    func showStakingManagement(
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        status: NominationViewStatus?,
        from _: ControllerBackedProtocol?
    ) -> StakingPoolManagementModuleInput? {
        managementStatuses.append(status)
        return managementInput
    }

    func showPoolValidators(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset, wallet _: fearless.MetaAccountModel) {
        poolValidatorsCount += 1
    }

    func showCreateNewWallet(from _: ControllerBackedProtocol?) { createWalletCount += 1 }
    func showImportWallet(defaultSource: AccountImportSource, from _: ControllerBackedProtocol?) { importSources.append(defaultSource) }
    func showBackupSelectWallet(from _: ControllerBackedProtocol?) { backupCount += 1 }
    func showGetPreinstalledWallet(from _: ControllerBackedProtocol?) { preinstalledCount += 1 }
}

final class CovCPMMainModuleOutputSpy: StakingMainModuleOutput {
    private(set) var switchedTypes: [AssetSelectionStakingType] = []
    func didSwitchStakingType(_ type: AssetSelectionStakingType) { switchedTypes.append(type) }
}

final class CovCPMMainSelectionViewStub: ChainSelectionViewProtocol {
    let hostController = UIViewController()
    var isSetup: Bool { true }
    var controller: UIViewController { hostController }
    func didReload() {}
    func bind(viewModel _: TextSearchViewModel?) {}
}

final class CovCPMMainPresenterCalculatorStub: RewardCalculatorEngineProtocol {
    var rewardAssetRate: Decimal { 1 }

    func calculateEarnings(amount: Decimal, validatorAccountId _: AccountId, isCompound _: Bool, period _: CalculationPeriod) throws -> Decimal {
        amount
    }

    func calculateMaxEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { amount }
    func calculateAvgEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { amount }

    func calculatorReturn(isCompound _: Bool, period _: CalculationPeriod, type: RewardReturnType) -> Decimal {
        if case .avg = type {
            return 0.1
        }
        return 0.2
    }

    func maxEarningsTitle(locale _: Locale) -> String { "max-title" }
    func avgEarningTitle(locale _: Locale) -> String { "avg-title" }
}

final class CovCPMMainPresenterLoggerSpy: LoggerProtocol {
    private(set) var errors: [String] = []

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message: String, file _: String, function _: String, line _: Int) { errors.append(message) }
    func customError(error: Error, file _: String, function _: String, line _: Int) { errors.append("\(error)") }
}

final class CovCPMMainPresenterContext {
    struct CovCTestError: Error {}

    let chainAsset: ChainAsset
    let wallet: fearless.MetaAccountModel
    let view = CovCPMMainPresenterViewSpy()
    let interactor = CovCPMMainPresenterInteractorSpy()
    let router = CovCPMMainPresenterRouterSpy()
    let moduleOutput = CovCPMMainModuleOutputSpy()
    let logger = CovCPMMainPresenterLoggerSpy()
    let presenter: StakingPoolMainPresenter

    init() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        chainAsset = ChainAsset(chain: chain, asset: asset)
        wallet = AccountGenerator.generateMetaAccount()
        presenter = StakingPoolMainPresenter(
            interactor: interactor,
            router: router,
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en")),
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet),
            moduleOutput: moduleOutput,
            viewModelFactory: StakingPoolMainViewModelFactory(wallet: wallet),
            chainAsset: chainAsset,
            wallet: wallet,
            logger: logger
        )
    }

    static func spin(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    static func member(points: BigUInt) throws -> StakingPoolMember {
        let json: [String: Any] = [
            "poolId": "5",
            "points": "\(points)",
            "lastRecordedRewardCounter": "0",
            "unbondingEras": [["era": "1", "value": "10000000000"]]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(StakingPoolMember.self, from: data)
    }

    static func nomination(targets: [Data]) throws -> Nomination {
        let json: [String: Any] = ["targets": targets.map { $0.base64EncodedString() }, "submittedIn": "1"]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Nomination.self, from: data)
    }

    static func pool(state: StakingPoolState) -> StakingPool {
        StakingPool(
            id: "5",
            info: StakingPoolInfo(
                points: BigUInt(100_000_000_000),
                state: state,
                memberCounter: 2,
                roles: StakingPoolRoles(depositor: Data(repeating: 4, count: 32))
            ),
            name: "Pool"
        )
    }

    static func accountInfo(free: BigUInt) -> AccountInfo {
        AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: free, reserved: 0, frozen: 0))
    }

    func provideFullStakeInfo(state: StakingPoolState, nomination: Nomination?) throws {
        presenter.didReceive(wallet: wallet)
        presenter.didReceive(era: 4)
        presenter.didReceive(nomination: nomination)
        presenter.didReceive(stakeInfo: try Self.member(points: BigUInt(40_000_000_000)))
        presenter.didReceive(pendingRewards: BigUInt(10_000_000_000))
        presenter.didReceive(stakingPool: Self.pool(state: state))
    }

    func lastNominatorStatus() -> NominationViewStatus? {
        (view.nominatorStates.last ?? nil)?.value(for: Locale(identifier: "en")).status
    }
}

final class CovCPMPoolMainPresenterViewOutputTests: XCTestCase {
    func testDidLoadSetsUpInteractorAndClearsNominatorState() throws {
        let context = try CovCPMMainPresenterContext()

        context.presenter.didLoad(view: context.view)
        CovCPMMainPresenterContext.spin { !context.view.nominatorStates.isEmpty }

        XCTAssertEqual(context.interactor.setupCount, 1)
        XCTAssertEqual(context.view.nominatorStates.count, 1)
        XCTAssertNil(context.view.nominatorStates.first ?? nil)
    }

    func testRewardInfoRequiresCalculator() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)

        context.presenter.performRewardInfoAction()
        XCTAssertTrue(context.router.rewardDetails.isEmpty)

        context.presenter.didReceive(rewardCalculatorEngine: CovCPMMainPresenterCalculatorStub())
        context.presenter.performRewardInfoAction()

        let details = try XCTUnwrap(context.router.rewardDetails.first)
        XCTAssertEqual(details.maxTitle, "max-title")
        XCTAssertEqual(details.max, 0.2)
        XCTAssertEqual(details.avgTitle, "avg-title")
        XCTAssertEqual(details.avg, 0.1)
    }

    func testAmountInputDrivesEstimationAndSetupAmount() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)

        context.presenter.didTapStartStaking()
        XCTAssertEqual(context.router.setupAmounts.count, 1)
        XCTAssertNil(context.router.setupAmounts.first ?? nil)

        context.presenter.didReceive(accountInfo: CovCPMMainPresenterContext.accountInfo(free: BigUInt(40_000_000_000)))
        context.presenter.updateAmount(3)
        CovCPMMainPresenterContext.spin { context.view.estimations.last?.amount == 3 }
        XCTAssertEqual(context.view.estimations.last?.amount, 3)

        context.presenter.selectAmountPercentage(0.5)
        CovCPMMainPresenterContext.spin { context.view.estimations.last?.amount == 2 }
        XCTAssertEqual(context.view.estimations.last?.amount, 2)

        context.presenter.didTapStartStaking()
        XCTAssertEqual(context.router.setupAmounts.last ?? nil, 2)
    }

    func testNavigationActions() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)

        context.presenter.didTapSelectAsset()
        context.presenter.didTapAccountSelection()
        context.presenter.networkInfoViewDidChangeExpansion(isExpanded: true)
        context.presenter.showAddNewWallet()
        context.presenter.showImportWallet(defaultSource: .seed)
        context.presenter.showImportGoogle()
        context.presenter.showGetPreinstalledWallet()

        XCTAssertEqual(context.router.assetSelectionTypes, [.pool(chainAsset: context.chainAsset)])
        XCTAssertEqual(context.router.accountsSelectionCount, 1)
        XCTAssertEqual(context.interactor.expansions, [true])
        XCTAssertEqual(context.router.createWalletCount, 1)
        XCTAssertEqual(context.router.importSources, [.seed])
        XCTAssertEqual(context.router.backupCount, 1)
        XCTAssertEqual(context.router.preinstalledCount, 1)
    }

    func testAssetSelectionHandlesContexts() throws {
        let context = try CovCPMMainPresenterContext()
        let selectionView = CovCPMMainSelectionViewStub()
        let other = CovCPMMainViewFixturesForPresenter.otherChainAsset()

        context.presenter.assetSelection(view: selectionView, didCompleteWith: other, context: nil)
        XCTAssertTrue(context.interactor.savedChainAssets.isEmpty)

        context.presenter.assetSelection(view: selectionView, didCompleteWith: other, context: AssetSelectionStakingType.pool(chainAsset: other))
        XCTAssertEqual(context.interactor.savedChainAssets.count, 1)
        XCTAssertTrue(context.moduleOutput.switchedTypes.isEmpty)

        let normal = AssetSelectionStakingType.normal(chainAsset: other)
        context.presenter.assetSelection(view: selectionView, didCompleteWith: other, context: normal)
        XCTAssertEqual(context.interactor.savedChainAssets.count, 2)
        XCTAssertEqual(context.moduleOutput.switchedTypes, [normal])
    }

    func testStakeInfoTapOpensManagementAndForwardsStatusChanges() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)
        try context.provideFullStakeInfo(state: .open, nomination: try CovCPMMainPresenterContext.nomination(targets: [Data(repeating: 1, count: 32)]))

        context.presenter.didTapStakeInfoView()

        guard case let .active(era)?? = context.router.managementStatuses.last else {
            return XCTFail("expected active status")
        }
        XCTAssertEqual(era, 4)

        context.presenter.didReceive(era: 6)
        guard case let .active(newEra)? = context.router.managementInput.statuses.last else {
            return XCTFail("expected forwarded status")
        }
        XCTAssertEqual(newEra, 6)
    }

    func testStatusTapRoutesByPoolState() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)

        context.presenter.didTapStatusView()
        XCTAssertEqual(context.router.poolValidatorsCount, 0)
        XCTAssertTrue(context.router.managementStatuses.isEmpty)

        try context.provideFullStakeInfo(state: .open, nomination: nil)
        context.presenter.didTapStatusView()
        XCTAssertEqual(context.router.poolValidatorsCount, 1)

        context.presenter.didReceive(nomination: try CovCPMMainPresenterContext.nomination(targets: [Data(repeating: 2, count: 32)]))
        context.presenter.didTapStatusView()
        XCTAssertEqual(context.router.managementStatuses.count, 1)

        context.presenter.didReceive(stakingPool: CovCPMMainPresenterContext.pool(state: .blocked))
        context.presenter.didTapStatusView()
        XCTAssertEqual(context.router.poolValidatorsCount, 1)
        XCTAssertEqual(context.router.managementStatuses.count, 1)
    }
}

enum CovCPMMainViewFixturesForPresenter {
    static func otherChainAsset() -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 2)
        let asset = ChainModelGenerator.generateAssetWithId("ksm", symbol: "KSM", assetPresicion: 12)
        return ChainAsset(chain: chain, asset: asset)
    }
}

final class CovCPMPoolMainPresenterInteractorOutputTests: XCTestCase {
    func testAccountInfoProvidesBalanceAndEstimation() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)

        context.presenter.didReceive(accountInfo: CovCPMMainPresenterContext.accountInfo(free: BigUInt(70_000_000_000)))
        CovCPMMainPresenterContext.spin { !context.view.balances.isEmpty && !context.view.estimations.isEmpty }

        XCTAssertEqual(context.view.balances.last?.amount.contains("7"), true)
        XCTAssertNotNil(context.view.estimations.last)
        XCTAssertNil(context.view.estimations.last?.rewardViewModel)
    }

    func testNilAccountInfoProvidesZeroBalance() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)

        context.presenter.didReceive(accountInfo: nil)
        CovCPMMainPresenterContext.spin { !context.view.balances.isEmpty }

        XCTAssertEqual(context.view.balances.last?.amount.contains("0"), true)
    }

    func testChainAssetWalletAndCalculatorUpdates() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)
        let other = CovCPMMainViewFixturesForPresenter.otherChainAsset()

        context.presenter.didReceive(chainAsset: other)
        XCTAssertEqual(context.view.chainAssets.last?.asset.symbol, "KSM")

        context.presenter.didReceive(wallet: AccountGenerator.generateMetaAccount())
        context.presenter.didReceive(rewardCalculatorEngine: CovCPMMainPresenterCalculatorStub())
        CovCPMMainPresenterContext.spin { context.view.estimations.last?.rewardViewModel != nil }

        XCTAssertNotNil(context.view.estimations.last?.rewardViewModel)
        XCTAssertEqual(context.view.estimations.last?.assetInfo.symbol, other.assetDisplayInfo.symbol)
    }

    func testNetworkInfoIsForwarded() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)
        context.presenter.didReceive(wallet: context.wallet)

        context.presenter.didReceive(networkInfo: StakingPoolNetworkInfo(
            minJoinBond: BigUInt(10_000_000_000),
            minCreateBond: nil,
            existingPoolsCount: 3,
            possiblePoolsCount: nil,
            maxMembersInPool: nil,
            maxPoolsMembers: 9
        ))

        XCTAssertEqual(context.view.networkInfos.last?.count, 3)
    }

    func testPoolAccountsAreRequestedOncePalletAndPoolAreKnown() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)

        context.presenter.didReceive(palletIdResult: .failure(CovCPMMainPresenterContext.CovCTestError()))
        context.presenter.didReceive(palletIdResult: .success(Data(repeating: 0xAB, count: 8)))
        XCTAssertTrue(context.interactor.poolBalanceRequests.isEmpty)

        context.presenter.didReceive(stakingPool: CovCPMMainPresenterContext.pool(state: .open))
        let rewardAccount = try XCTUnwrap(context.interactor.poolBalanceRequests.last)
        let stashAccount = try XCTUnwrap(context.interactor.nominationRequests.last)
        XCTAssertEqual(rewardAccount.count, 32)
        XCTAssertEqual(rewardAccount[rewardAccount.startIndex + 12], PoolAccount.rewards.rawValue)
        XCTAssertEqual(stashAccount[stashAccount.startIndex + 12], PoolAccount.stash.rawValue)

        context.presenter.didReceive(palletIdResult: .success(Data(repeating: 0xCD, count: 8)))
        XCTAssertEqual(context.interactor.poolBalanceRequests.count, 2)

        context.presenter.didReceive(stakeInfo: nil)
        XCTAssertEqual(context.interactor.nominationRequests.count, 3)
    }

    func testFullStakeInfoProducesNominatorState() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)

        try context.provideFullStakeInfo(state: .open, nomination: nil)
        CovCPMMainPresenterContext.spin {
            guard case .validatorsNotSelected? = context.lastNominatorStatus() else { return false }
            return true
        }

        guard case .validatorsNotSelected? = context.lastNominatorStatus() else {
            return XCTFail("expected validatorsNotSelected")
        }
        let viewModel = try XCTUnwrap((context.view.nominatorStates.last ?? nil)?.value(for: Locale(identifier: "en")))
        XCTAssertTrue(viewModel.totalStakedAmount.contains("4"))
        XCTAssertTrue(viewModel.totalRewardAmount.contains("1"))

        context.presenter.didReceive(eraStakersInfo: EraStakersInfo(activeEra: 4, validators: []))
        context.presenter.didReceive(poolRewards: nil)
        context.presenter.didReceive(poolAccountInfo: nil)
        context.presenter.didReceive(existentialDepositResult: .success(BigUInt(1)))
        context.presenter.didReceive(stakingPool: CovCPMMainPresenterContext.pool(state: .destroying))
        CovCPMMainPresenterContext.spin {
            guard case .inactive? = context.lastNominatorStatus() else { return false }
            return true
        }
        guard case let .inactive(era)? = context.lastNominatorStatus() else {
            return XCTFail("expected inactive")
        }
        XCTAssertEqual(era, 4)
    }

    func testMissingPendingRewardsClearsNominatorState() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)
        try context.provideFullStakeInfo(state: .open, nomination: nil)

        context.presenter.didReceive(pendingRewards: nil)
        CovCPMMainPresenterContext.spin { context.view.nominatorStates.count > 1 && (context.view.nominatorStates.last ?? nil) == nil }

        XCTAssertNil(context.view.nominatorStates.last ?? nil)
    }

    func testErrorsAreLogged() throws {
        let context = try CovCPMMainPresenterContext()
        context.presenter.didLoad(view: context.view)

        context.presenter.didReceive(eraCountdownResult: .failure(CovCPMMainPresenterContext.CovCTestError()))
        context.presenter.didReceive(existentialDepositResult: .failure(CovCPMMainPresenterContext.CovCTestError()))
        context.presenter.didReceiveError(.balanceError(error: CovCPMMainPresenterContext.CovCTestError()))
        context.presenter.didReceive(pendingRewardsError: CovCPMMainPresenterContext.CovCTestError())
        XCTAssertEqual(context.logger.errors.count, 4)

        let countdown = EraCountdown(
            activeEra: 1,
            currentEra: 1,
            eraLength: 6,
            sessionLength: 10,
            activeEraStartSessionIndex: 0,
            currentSessionIndex: 0,
            currentSlot: 0,
            genesisSlot: 0,
            blockCreationTime: 6000,
            createdAtDate: Date()
        )
        context.presenter.didReceive(eraCountdownResult: .success(countdown))
        context.presenter.applyLocalization()
        XCTAssertEqual(context.logger.errors.count, 4)
    }
}
