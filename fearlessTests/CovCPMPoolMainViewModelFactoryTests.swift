import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPMMainFactoryCalculatorStub: RewardCalculatorEngineProtocol {
    var rewardAssetRate: Decimal { 1 }

    func calculateEarnings(amount: Decimal, validatorAccountId _: AccountId, isCompound _: Bool, period _: CalculationPeriod) throws -> Decimal {
        amount
    }

    func calculateMaxEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { amount }
    func calculateAvgEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { amount }

    func calculatorReturn(isCompound _: Bool, period: CalculationPeriod, type _: RewardReturnType) -> Decimal {
        switch period {
        case .month:
            return 0.01
        default:
            return 0.12
        }
    }

    func maxEarningsTitle(locale _: Locale) -> String { "max" }
    func avgEarningTitle(locale _: Locale) -> String { "avg" }
}

enum CovCPMMainFactoryFixtures {
    static func member(points: BigUInt, unbonding: [(era: UInt32, value: BigUInt)]) throws -> StakingPoolMember {
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
}

final class CovCPMPoolMainViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!

    override func setUp() {
        super.setUp()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        chainAsset = ChainAsset(chain: chain, asset: asset)
        wallet = AccountGenerator.generateMetaAccount()
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        super.tearDown()
    }

    private func makeFactory(withBalanceFactory: Bool = true) -> StakingPoolMainViewModelFactory {
        let factory = StakingPoolMainViewModelFactory(wallet: wallet)
        if withBalanceFactory {
            factory.replaceBalanceViewModelFactory(
                balanceViewModelFactory: BalanceViewModelFactory(
                    targetAssetInfo: chainAsset.assetDisplayInfo,
                    selectedMetaAccount: wallet
                )
            )
        }
        return factory
    }

    private func status(of resource: LocalizableResource<NominationViewModelProtocol>?) -> NominationViewStatus? {
        resource?.value(for: locale).status
    }

    func testEstimationWithoutCalculatorHasNoReward() {
        let factory = makeFactory(withBalanceFactory: false)
        let accountInfo = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: BigUInt(30_000_000_000), reserved: 0, frozen: BigUInt(10_000_000_000))
        )

        let viewModel = factory.createEstimationViewModel(
            for: chainAsset,
            accountInfo: accountInfo,
            amount: 1.5,
            priceData: nil,
            calculatorEngine: nil
        )

        XCTAssertNil(viewModel.rewardViewModel)
        XCTAssertEqual(viewModel.amount, 1.5)
        XCTAssertEqual(viewModel.inputLimit, StakingConstants.maxAmount)
        XCTAssertEqual(viewModel.assetInfo.symbol, chainAsset.assetDisplayInfo.symbol)
        XCTAssertEqual(viewModel.assetBalance.value(for: locale).balance?.contains("2"), true)
        XCTAssertNotNil(factory.balanceViewModelFactory)
    }

    func testEstimationWithCalculatorProducesPeriodRewards() throws {
        let factory = makeFactory()

        let viewModel = factory.createEstimationViewModel(
            for: chainAsset,
            accountInfo: nil,
            amount: 100,
            priceData: nil,
            calculatorEngine: CovCPMMainFactoryCalculatorStub()
        )

        let reward = try XCTUnwrap(viewModel.rewardViewModel?.value(for: locale))
        XCTAssertTrue(reward.monthlyReward.amount.contains("1"))
        XCTAssertTrue(reward.yearlyReward.amount.contains("12"))
        XCTAssertNotNil(reward.monthlyReward.increase)
        XCTAssertNotNil(reward.yearlyReward.increase)
    }

    func testEstimationWithoutAmountUsesZero() throws {
        let factory = makeFactory()

        let viewModel = factory.createEstimationViewModel(
            for: chainAsset,
            accountInfo: nil,
            amount: nil,
            priceData: nil,
            calculatorEngine: CovCPMMainFactoryCalculatorStub()
        )

        XCTAssertNil(viewModel.amount)
        let reward = try XCTUnwrap(viewModel.rewardViewModel?.value(for: locale))
        XCTAssertTrue(reward.monthlyReward.amount.contains("0"))
    }

    func testNetworkInfoWithAllValues() {
        let factory = makeFactory()
        let info = StakingPoolNetworkInfo(
            minJoinBond: BigUInt(10_000_000_000),
            minCreateBond: BigUInt(20_000_000_000),
            existingPoolsCount: 11,
            possiblePoolsCount: 22,
            maxMembersInPool: 33,
            maxPoolsMembers: 44
        )

        let viewModels = factory.buildNetworkInfoViewModels(networkInfo: info, chainAsset: chainAsset).map { $0.value(for: locale) }

        XCTAssertEqual(viewModels.count, 6)
        let languages = ["en"]
        XCTAssertEqual(viewModels[0].title, R.string.localizable.poolStakingMainMinJoinTitle(preferredLanguages: languages))
        XCTAssertTrue(viewModels[0].value.contains("1"))
        XCTAssertEqual(viewModels[1].title, R.string.localizable.poolStakingMainMinCreateTitle(preferredLanguages: languages))
        XCTAssertTrue(viewModels[1].value.contains("2"))
        XCTAssertEqual(viewModels[2].title, R.string.localizable.poolStakingMainExistingPoolsTitle(preferredLanguages: languages))
        XCTAssertEqual(viewModels[2].value, "11")
        XCTAssertEqual(viewModels[3].title, R.string.localizable.poolStakingMainPossiblePoolsTitle(preferredLanguages: languages))
        XCTAssertEqual(viewModels[3].value, "22")
        XCTAssertEqual(viewModels[4].title, R.string.localizable.poolStakingMainMaxMembersInpoolTitle(preferredLanguages: languages))
        XCTAssertEqual(viewModels[4].value, "33")
        XCTAssertEqual(viewModels[5].title, R.string.localizable.poolStakingMainMaxPoolMembersTitle(preferredLanguages: languages))
        XCTAssertEqual(viewModels[5].value, "44")
        XCTAssertTrue(viewModels.allSatisfy { $0.details == nil })
    }

    func testNetworkInfoWithoutBalanceFactoryLeavesAmountsEmpty() {
        let factory = makeFactory(withBalanceFactory: false)
        let info = StakingPoolNetworkInfo(
            minJoinBond: BigUInt(1),
            minCreateBond: BigUInt(2),
            existingPoolsCount: nil,
            possiblePoolsCount: nil,
            maxMembersInPool: nil,
            maxPoolsMembers: nil
        )

        let viewModels = factory.buildNetworkInfoViewModels(networkInfo: info, chainAsset: chainAsset).map { $0.value(for: locale) }

        XCTAssertEqual(viewModels.count, 2)
        XCTAssertEqual(viewModels.map(\.value), ["", ""])
    }

    func testNetworkInfoWithoutValuesIsEmpty() {
        let factory = makeFactory()
        let info = StakingPoolNetworkInfo(
            minJoinBond: nil,
            minCreateBond: nil,
            existingPoolsCount: nil,
            possiblePoolsCount: nil,
            maxMembersInPool: nil,
            maxPoolsMembers: nil
        )

        XCTAssertTrue(factory.buildNetworkInfoViewModels(networkInfo: info, chainAsset: chainAsset).isEmpty)
    }

    func testNominatorStateRequiresBalanceFactory() throws {
        let factory = makeFactory(withBalanceFactory: false)

        let resource = factory.buildNominatorStateViewModel(
            stakeInfo: try CovCPMMainFactoryFixtures.member(points: 1, unbonding: []),
            chainAsset: chainAsset,
            era: 3,
            poolInfo: CovCPMMainFactoryFixtures.pool(state: .open),
            nomination: nil,
            pendingRewards: 0
        )

        XCTAssertNil(resource)
    }

    func testNominatorStateActiveWithRedeemableAndUnstaking() throws {
        let factory = makeFactory()
        let member = try CovCPMMainFactoryFixtures.member(
            points: BigUInt(50_000_000_000),
            unbonding: [(era: 2, value: BigUInt(10_000_000_000)), (era: 9, value: BigUInt(30_000_000_000))]
        )

        let resource = factory.buildNominatorStateViewModel(
            stakeInfo: member,
            chainAsset: chainAsset,
            era: 5,
            poolInfo: CovCPMMainFactoryFixtures.pool(state: .open),
            nomination: try CovCPMMainFactoryFixtures.nomination(targets: [Data(repeating: 1, count: 32)]),
            pendingRewards: BigUInt(20_000_000_000)
        )

        let viewModel = try XCTUnwrap(resource?.value(for: locale))
        guard case let .active(era) = viewModel.status else {
            return XCTFail("expected active")
        }
        XCTAssertEqual(era, 5)
        XCTAssertTrue(viewModel.totalStakedAmount.contains("5"))
        XCTAssertTrue(viewModel.totalRewardAmount.contains("2"))
        XCTAssertEqual(viewModel.redeemableViewModel?.value?.contains("1"), true)
        XCTAssertEqual(viewModel.unstakingViewModel?.value?.contains("3"), true)
        XCTAssertFalse(viewModel.hasPrice)
        XCTAssertEqual(viewModel.rewardViewTitle, R.string.localizable.poolClaimableTitle(preferredLanguages: ["en"]))
    }

    func testNominatorStateOpenWithoutNominationNeedsValidators() throws {
        let factory = makeFactory()

        let resource = factory.buildNominatorStateViewModel(
            stakeInfo: try CovCPMMainFactoryFixtures.member(points: 1, unbonding: []),
            chainAsset: chainAsset,
            era: 8,
            poolInfo: CovCPMMainFactoryFixtures.pool(state: .open),
            nomination: try CovCPMMainFactoryFixtures.nomination(targets: []),
            pendingRewards: 0
        )

        guard case .validatorsNotSelected? = status(of: resource) else {
            return XCTFail("expected validatorsNotSelected")
        }
    }

    func testNominatorStateWithoutEraIsUndefinedAndHasNoUnbondingInfo() throws {
        let factory = makeFactory()

        let openResource = factory.buildNominatorStateViewModel(
            stakeInfo: try CovCPMMainFactoryFixtures.member(points: 1, unbonding: []),
            chainAsset: chainAsset,
            era: nil,
            poolInfo: CovCPMMainFactoryFixtures.pool(state: .open),
            nomination: nil,
            pendingRewards: 0
        )
        let destroyingResource = factory.buildNominatorStateViewModel(
            stakeInfo: try CovCPMMainFactoryFixtures.member(points: 1, unbonding: []),
            chainAsset: chainAsset,
            era: nil,
            poolInfo: CovCPMMainFactoryFixtures.pool(state: .destroying),
            nomination: nil,
            pendingRewards: 0
        )

        guard case .undefined? = status(of: openResource), case .undefined? = status(of: destroyingResource) else {
            return XCTFail("expected undefined")
        }
        XCTAssertNil(openResource?.value(for: locale).redeemableViewModel)
        XCTAssertNil(openResource?.value(for: locale).unstakingViewModel)
    }

    func testNominatorStateBlockedPoolIsInactive() throws {
        let factory = makeFactory()

        let resource = factory.buildNominatorStateViewModel(
            stakeInfo: try CovCPMMainFactoryFixtures.member(points: 1, unbonding: []),
            chainAsset: chainAsset,
            era: 4,
            poolInfo: CovCPMMainFactoryFixtures.pool(state: .blocked),
            nomination: nil,
            pendingRewards: 0
        )

        guard case let .inactive(era)? = status(of: resource) else {
            return XCTFail("expected inactive")
        }
        XCTAssertEqual(era, 4)
    }
}
