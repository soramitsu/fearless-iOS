import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPMMgmtViewSpy: StakingPoolManagementViewInput {
    let hostController = UIViewController()
    private(set) var poolNames: [String?] = []
    private(set) var balances: [BalanceViewModelProtocol?] = []
    private(set) var unstakings: [BalanceViewModelProtocol?] = []
    private(set) var stakedStrings: [NSAttributedString] = []
    private(set) var redeemDelays: [LocalizableResource<String>?] = []
    private(set) var claimables: [BalanceViewModelProtocol?] = []
    private(set) var redeemables: [BalanceViewModelProtocol?] = []
    private(set) var viewModels: [StakingPoolManagementViewModel] = []
    private(set) var selectValidatorVisibility: [Bool] = []

    var isSetup: Bool { true }
    var controller: UIViewController { hostController }

    func didReceive(poolName: String?) { poolNames.append(poolName) }
    func didReceive(balanceViewModel: BalanceViewModelProtocol?) { balances.append(balanceViewModel) }
    func didReceive(unstakingViewModel: BalanceViewModelProtocol?) { unstakings.append(unstakingViewModel) }
    func didReceive(stakedAmountString: NSAttributedString) { stakedStrings.append(stakedAmountString) }
    func didReceive(redeemDelayViewModel: LocalizableResource<String>?) { redeemDelays.append(redeemDelayViewModel) }
    func didReceive(claimableViewModel: BalanceViewModelProtocol?) { claimables.append(claimableViewModel) }
    func didReceive(redeemableViewModel: BalanceViewModelProtocol?) { redeemables.append(redeemableViewModel) }
    func didReceive(viewModel: StakingPoolManagementViewModel) { viewModels.append(viewModel) }
    func didReceiveSelectValidator(visible: Bool) { selectValidatorVisibility.append(visible) }
}

final class CovCPMMgmtInteractorSpy: StakingPoolManagementInteractorInput {
    private(set) var setupCount = 0
    private(set) var poolBalanceRequests: [AccountId] = []
    private(set) var nominationRequests: [AccountId] = []

    func setup(with _: StakingPoolManagementInteractorOutput) { setupCount += 1 }
    func fetchPoolBalance(poolAccountId: AccountId) { poolBalanceRequests.append(poolAccountId) }
    func fetchPoolNomination(poolStashAccountId: AccountId) { nominationRequests.append(poolStashAccountId) }
}

final class CovCPMMgmtPoolInfoInputSpy: StakingPoolInfoModuleInput {
    private(set) var statuses: [NominationViewStatus] = []
    func didChange(status: NominationViewStatus) { statuses.append(status) }
}

final class CovCPMMgmtRouterSpy: StakingPoolManagementRouterInput {
    let poolInfoInput = CovCPMMgmtPoolInfoInputSpy()
    private(set) var dismissCount = 0
    private(set) var stakeMoreFlows: [StakingBondMoreFlow] = []
    private(set) var unbondFlows: [StakingUnbondSetupFlow] = []
    private(set) var poolInfoRequests: [(poolId: String, status: NominationViewStatus?)] = []
    private(set) var optionViewModels: [[TitleWithSubtitleViewModel]] = []
    private(set) var optionCallbacks: [ModalPickerSelectionCallback] = []
    private(set) var claimAmounts: [Decimal] = []
    private(set) var redeemFlows: [StakingRedeemConfirmationFlow] = []
    private(set) var selectValidators: [(poolId: UInt32, amount: Decimal)] = []

    func dismiss(view _: ControllerBackedProtocol?) { dismissCount += 1 }

    func presentStakeMoreFlow(flow: StakingBondMoreFlow, chainAsset _: ChainAsset, wallet _: fearless.MetaAccountModel, from _: ControllerBackedProtocol?) {
        stakeMoreFlows.append(flow)
    }

    func presentUnbondFlow(flow: StakingUnbondSetupFlow, chainAsset _: ChainAsset, wallet _: fearless.MetaAccountModel, from _: ControllerBackedProtocol?) {
        unbondFlows.append(flow)
    }

    func presentPoolInfo(
        stakingPool: StakingPool,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        status: NominationViewStatus?,
        from _: ControllerBackedProtocol?
    ) -> StakingPoolInfoModuleInput? {
        poolInfoRequests.append((stakingPool.id, status))
        return poolInfoInput
    }

    func presentOptions(viewModels: [TitleWithSubtitleViewModel], callback: ModalPickerSelectionCallback?, from _: ControllerBackedProtocol?) {
        optionViewModels.append(viewModels)
        if let callback = callback {
            optionCallbacks.append(callback)
        }
    }

    func presentClaim(rewardAmount: Decimal, chainAsset _: ChainAsset, wallet _: fearless.MetaAccountModel, from _: ControllerBackedProtocol?) {
        claimAmounts.append(rewardAmount)
    }

    func presentRedeemFlow(
        flow: StakingRedeemConfirmationFlow,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        from _: ControllerBackedProtocol?
    ) {
        redeemFlows.append(flow)
    }

    func proceedToSelectValidatorsStart(
        from _: ControllerBackedProtocol?,
        poolId: UInt32,
        state: InitiatedBonding,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel
    ) {
        selectValidators.append((poolId, state.amount))
    }
}

final class CovCPMMgmtLoggerSpy: LoggerProtocol {
    private(set) var errors: [String] = []

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message: String, file _: String, function _: String, line _: Int) { errors.append(message) }
    func customError(error: Error, file _: String, function _: String, line _: Int) { errors.append("\(error)") }
}

final class CovCPMMgmtContext {
    struct CovCTestError: Error {}

    let chainAsset: ChainAsset
    let wallet: fearless.MetaAccountModel
    let view = CovCPMMgmtViewSpy()
    let interactor = CovCPMMgmtInteractorSpy()
    let router = CovCPMMgmtRouterSpy()
    let logger = CovCPMMgmtLoggerSpy()
    let presenter: StakingPoolManagementPresenter

    init(status: NominationViewStatus? = nil) throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        chainAsset = ChainAsset(chain: chain, asset: asset)
        wallet = AccountGenerator.generateMetaAccount()
        presenter = StakingPoolManagementPresenter(
            interactor: interactor,
            router: router,
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en")),
            chainAsset: chainAsset,
            wallet: wallet,
            viewModelFactory: StakingPoolManagementViewModelFactory(chainAsset: chainAsset),
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet),
            rewardCalculator: StakinkPoolRewardCalculator(),
            status: status,
            logger: logger
        )
        presenter.didLoad(view: view)
    }

    static func member(points: BigUInt, unbonding: [(era: UInt32, value: BigUInt)] = []) throws -> StakingPoolMember {
        let json: [String: Any] = [
            "poolId": "5",
            "points": "\(points)",
            "lastRecordedRewardCounter": "0",
            "unbondingEras": unbonding.map { ["era": "\($0.era)", "value": "\($0.value)"] }
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(StakingPoolMember.self, from: data)
    }

    static func nomination(targets: [Data]) throws -> Nomination {
        let json: [String: Any] = ["targets": targets.map { $0.base64EncodedString() }, "submittedIn": "1"]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Nomination.self, from: data)
    }

    func pool(name: String = "Pool", nominator: AccountId? = nil) -> StakingPool {
        StakingPool(
            id: "5",
            info: StakingPoolInfo(
                points: BigUInt(100_000_000_000),
                state: .open,
                memberCounter: 2,
                roles: StakingPoolRoles(depositor: Data(repeating: 4, count: 32), nominator: nominator)
            ),
            name: name
        )
    }
}

final class CovCPMPoolManagementPresenterActionTests: XCTestCase {
    func testDidLoadAndSimpleRoutes() throws {
        let context = try CovCPMMgmtContext()

        context.presenter.didTapCloseButton()
        context.presenter.didTapStakeMoreButton()
        context.presenter.didTapUnstakeButton()
        context.presenter.didTapRedeemButton()

        XCTAssertEqual(context.interactor.setupCount, 1)
        XCTAssertEqual(context.router.dismissCount, 1)
        XCTAssertEqual(context.router.stakeMoreFlows, [.pool])
        XCTAssertEqual(context.router.unbondFlows, [.pool])
        XCTAssertEqual(context.router.redeemFlows, [.pool])
    }

    func testOptionsMenuCallbacksRouteToValidatorsAndPoolInfo() throws {
        let context = try CovCPMMgmtContext(status: .active(era: 2))

        context.presenter.didTapOptionsButton()

        let viewModels = try XCTUnwrap(context.router.optionViewModels.first)
        XCTAssertEqual(viewModels.map(\.title), [
            R.string.localizable.poolStakingManagementOptionNominees(preferredLanguages: ["en"]),
            R.string.localizable.stakingPoolInfoTitle(preferredLanguages: ["en"]).capitalized
        ])
        let callback = try XCTUnwrap(context.router.optionCallbacks.first)

        callback(0)
        callback(1)
        XCTAssertTrue(context.router.selectValidators.isEmpty)
        XCTAssertTrue(context.router.poolInfoRequests.isEmpty)

        context.presenter.didReceive(stakeInfo: try CovCPMMgmtContext.member(points: BigUInt(30_000_000_000)))
        context.presenter.didReceive(stakingPool: context.pool())
        callback(0)
        callback(1)

        XCTAssertEqual(context.router.selectValidators.first?.poolId, 5)
        XCTAssertEqual(context.router.selectValidators.first?.amount, 3)
        XCTAssertEqual(context.router.poolInfoRequests.first?.poolId, "5")
        guard case let .active(era)?? = context.router.poolInfoRequests.first?.status else {
            return XCTFail("expected active status")
        }
        XCTAssertEqual(era, 2)
    }

    func testPoolInfoTapAndStatusForwarding() throws {
        let context = try CovCPMMgmtContext()
        context.presenter.didTapPoolInfoName()
        XCTAssertTrue(context.router.poolInfoRequests.isEmpty)

        context.presenter.didReceive(stakingPool: context.pool())
        context.presenter.didTapPoolInfoName()
        context.presenter.didChange(status: .inactive(era: 8))

        XCTAssertEqual(context.router.poolInfoRequests.count, 1)
        guard case let .inactive(era)? = context.router.poolInfoInput.statuses.last else {
            return XCTFail("expected forwarded status")
        }
        XCTAssertEqual(era, 8)

        context.presenter.didTapPoolInfoName()
        guard case .inactive?? = context.router.poolInfoRequests.last?.status else {
            return XCTFail("expected stored status")
        }
    }

    func testClaimRequiresPositivePendingRewards() throws {
        let context = try CovCPMMgmtContext()

        context.presenter.didTapClaimButton()
        context.presenter.didReceive(pendingRewards: BigUInt.zero)
        context.presenter.didTapClaimButton()
        XCTAssertTrue(context.router.claimAmounts.isEmpty)

        context.presenter.didReceive(pendingRewards: BigUInt(5_000_000_000))
        context.presenter.didTapClaimButton()
        XCTAssertEqual(context.router.claimAmounts, [0.5])
    }

    func testSelectValidatorsRequiresStakeInfo() throws {
        let context = try CovCPMMgmtContext()

        context.presenter.didTapSelectValidators()
        XCTAssertTrue(context.router.selectValidators.isEmpty)

        context.presenter.didReceive(stakeInfo: try CovCPMMgmtContext.member(points: BigUInt(10_000_000_000)))
        context.presenter.didTapSelectValidators()
        XCTAssertEqual(context.router.selectValidators.first?.amount, 1)
    }
}

final class CovCPMPoolManagementPresenterOutputTests: XCTestCase {
    func testStakeInfoProvidesAmountsAndButtons() throws {
        let context = try CovCPMMgmtContext()

        context.presenter.didReceive(stakeInfo: try CovCPMMgmtContext.member(points: BigUInt(25_000_000_000)))

        XCTAssertNil(context.view.unstakings.last ?? nil)
        XCTAssertEqual(context.view.stakedStrings.last?.string.contains("2.5"), true)
        XCTAssertEqual(context.view.viewModels.last?.stakeMoreButtonVisible, true)
        XCTAssertEqual(context.view.viewModels.last?.unstakeButtonVisible, true)
        XCTAssertNil(context.view.redeemDelays.last ?? nil)
        XCTAssertNil(context.view.claimables.last ?? nil)
        XCTAssertTrue(context.view.redeemables.isEmpty)
    }

    func testEraStakersAndDurationProvideUnbondingDetails() throws {
        let context = try CovCPMMgmtContext()
        let member = try CovCPMMgmtContext.member(
            points: BigUInt(25_000_000_000),
            unbonding: [(era: 3, value: BigUInt(20_000_000_000)), (era: 12, value: BigUInt(10_000_000_000))]
        )
        context.presenter.didReceive(stakeInfo: member)

        context.presenter.didReceive(eraStakersInfo: EraStakersInfo(activeEra: 10, validators: []))
        XCTAssertEqual((context.view.unstakings.last ?? nil)?.amount.contains("1"), true)
        XCTAssertEqual((context.view.redeemables.last ?? nil)?.amount.contains("2"), true)

        context.presenter.didReceive(stakingDuration: StakingDuration(session: 3600, era: TimeInterval.secondsInDay, unlocking: 0))
        XCTAssertNil(context.view.redeemDelays.last ?? nil)

        context.presenter.didReceive(stakeInfo: try CovCPMMgmtContext.member(
            points: BigUInt(25_000_000_000),
            unbonding: [(era: 12, value: BigUInt(10_000_000_000))]
        ))
        let delay = try XCTUnwrap(context.view.redeemDelays.last ?? nil)
        XCTAssertEqual(delay.value(for: Locale(identifier: "en")), R.string.localizable.commonDaysFormat(format: 2, preferredLanguages: ["en"]))
    }

    func testAccountInfoResults() throws {
        let context = try CovCPMMgmtContext()

        context.presenter.didReceiveAccountInfo(result: .success(nil))
        XCTAssertTrue(context.view.balances.isEmpty)

        let info = AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: BigUInt(60_000_000_000), reserved: 0, frozen: 0))
        context.presenter.didReceiveAccountInfo(result: .success(info))
        XCTAssertEqual((context.view.balances.last ?? nil)?.amount.contains("6"), true)

        context.presenter.didReceiveAccountInfo(result: .failure(CovCPMMgmtContext.CovCTestError()))
        XCTAssertEqual(context.logger.errors.count, 1)
    }

    func testStakingPoolNameFallbacks() throws {
        let context = try CovCPMMgmtContext()

        context.presenter.didReceive(stakingPool: context.pool(name: "Named"))
        context.presenter.didReceive(stakingPool: context.pool(name: ""))
        context.presenter.didReceive(stakingPool: nil)

        XCTAssertEqual(context.view.poolNames.count, 3)
        XCTAssertEqual(context.view.poolNames[0], "Named")
        XCTAssertEqual(context.view.poolNames[1], "5")
        XCTAssertNil(context.view.poolNames[2])
    }

    func testPalletAndPoolTriggerPoolAccountRequests() throws {
        let context = try CovCPMMgmtContext()

        context.presenter.didReceive(palletIdResult: .failure(CovCPMMgmtContext.CovCTestError()))
        XCTAssertEqual(context.logger.errors.count, 1)

        context.presenter.didReceive(palletIdResult: .success(Data(repeating: 7, count: 8)))
        XCTAssertTrue(context.interactor.poolBalanceRequests.isEmpty)

        context.presenter.didReceive(stakingPool: context.pool())
        let rewards = try XCTUnwrap(context.interactor.poolBalanceRequests.last)
        let stash = try XCTUnwrap(context.interactor.nominationRequests.last)
        XCTAssertEqual(rewards.count, 32)
        XCTAssertEqual(rewards[rewards.startIndex + 12], PoolAccount.rewards.rawValue)
        XCTAssertEqual(stash[stash.startIndex + 12], PoolAccount.stash.rawValue)
        XCTAssertEqual(rewards[rewards.startIndex + 13], 5)
    }

    func testNominationControlsSelectValidatorsAlert() throws {
        let context = try CovCPMMgmtContext()
        let accountId = try XCTUnwrap(context.wallet.substrateAccountId)

        context.presenter.didReceive(stakingPool: context.pool(nominator: accountId))
        context.presenter.didReceive(nomination: nil)
        context.presenter.didReceive(nomination: try CovCPMMgmtContext.nomination(targets: []))
        context.presenter.didReceive(nomination: try CovCPMMgmtContext.nomination(targets: [Data(repeating: 1, count: 32)]))
        context.presenter.didReceive(stakingPool: context.pool(nominator: Data(repeating: 9, count: 32)))
        context.presenter.didReceive(nomination: try CovCPMMgmtContext.nomination(targets: []))

        XCTAssertEqual(context.view.selectValidatorVisibility, [true, true, false, false])
    }

    func testClaimableUpdatesFromRewardInputs() throws {
        let context = try CovCPMMgmtContext()

        context.presenter.didReceive(pendingRewards: BigUInt(15_000_000_000))
        XCTAssertEqual((context.view.claimables.last ?? nil)?.amount.contains("1.5"), true)

        context.presenter.didReceive(poolRewards: nil)
        context.presenter.didReceive(poolAccountInfo: nil)
        context.presenter.didReceive(existentialDepositResult: .success(BigUInt(1)))
        XCTAssertEqual(context.view.claimables.count, 4)

        context.presenter.didReceive(pendingRewards: nil)
        XCTAssertNil(context.view.claimables.last ?? nil)
    }

    func testErrorsAndIgnoredCallbacks() throws {
        let context = try CovCPMMgmtContext()
        let error = CovCPMMgmtContext.CovCTestError()

        context.presenter.didReceive(stakeInfoError: error)
        context.presenter.didReceive(eraCountdownResult: .failure(error))
        context.presenter.didReceive(eraStakersInfoError: error)
        context.presenter.didReceive(poolRewardsError: error)
        context.presenter.didReceiveValidators(result: .success([]))
        context.presenter.applyLocalization()
        XCTAssertTrue(context.logger.errors.isEmpty)

        context.presenter.didReceive(error: error)
        context.presenter.didReceive(existentialDepositResult: .failure(error))
        context.presenter.didReceiveValidators(result: .failure(error))
        context.presenter.didReceive(pendingRewardsError: error)
        XCTAssertEqual(context.logger.errors.count, 4)
    }
}

final class CovCPMPoolManagementViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private var factory: StakingPoolManagementViewModelFactory!

    override func setUp() {
        super.setUp()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        factory = StakingPoolManagementViewModelFactory(chainAsset: ChainAsset(chain: chain, asset: asset))
    }

    override func tearDown() {
        factory = nil
        super.tearDown()
    }

    func testStakedAmountString() {
        let string = factory.createStakedAmountViewModel(2.5).value(for: locale).string

        XCTAssertTrue(string.contains("2.5"))
    }

    func testUnstakeViewModelGuards() throws {
        let duration = StakingDuration(session: 1, era: TimeInterval.secondsInDay, unlocking: 1)
        let pastMember = try CovCPMMgmtContext.member(points: 1, unbonding: [(era: 2, value: 1)])
        let noChunks = try CovCPMMgmtContext.member(points: 1)

        XCTAssertNil(factory.buildUnstakeViewModel(stakingInfo: nil, activeEra: 1, stakingDuration: duration))
        XCTAssertNil(factory.buildUnstakeViewModel(stakingInfo: pastMember, activeEra: nil, stakingDuration: duration))
        XCTAssertNil(factory.buildUnstakeViewModel(stakingInfo: pastMember, activeEra: 1, stakingDuration: nil))
        XCTAssertNil(factory.buildUnstakeViewModel(stakingInfo: noChunks, activeEra: 1, stakingDuration: duration))
        XCTAssertNil(factory.buildUnstakeViewModel(stakingInfo: pastMember, activeEra: 2, stakingDuration: duration))

        let resource = factory.buildUnstakeViewModel(stakingInfo: pastMember, activeEra: 1, stakingDuration: duration)
        XCTAssertEqual(resource?.value(for: locale), R.string.localizable.commonDaysFormat(format: 1, preferredLanguages: ["en"]))
    }

    func testButtonVisibility() throws {
        let wallet = AccountGenerator.generateMetaAccount()

        let none = factory.buildViewModel(stakeInfo: nil, stakingPool: nil, wallet: wallet)
        XCTAssertTrue(none.stakeMoreButtonVisible)
        XCTAssertFalse(none.unstakeButtonVisible)

        let zero = factory.buildViewModel(stakeInfo: try CovCPMMgmtContext.member(points: 0), stakingPool: nil, wallet: wallet)
        XCTAssertFalse(zero.stakeMoreButtonVisible)
        XCTAssertFalse(zero.unstakeButtonVisible)

        let staked = factory.buildViewModel(stakeInfo: try CovCPMMgmtContext.member(points: 3), stakingPool: nil, wallet: wallet)
        XCTAssertTrue(staked.stakeMoreButtonVisible)
        XCTAssertTrue(staked.unstakeButtonVisible)
    }

    func testOptionsPickerViewModels() {
        let viewModels = factory.buildOptionsPickerViewModels(locale: locale)

        XCTAssertEqual(viewModels.map(\.title), [
            R.string.localizable.stakingValidatorNominators(preferredLanguages: ["en"]),
            R.string.localizable.poolCommon(preferredLanguages: ["en"])
        ])
        XCTAssertTrue(viewModels.allSatisfy { $0.icon == nil })
    }
}
