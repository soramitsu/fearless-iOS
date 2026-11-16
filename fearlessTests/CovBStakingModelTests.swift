import XCTest
import BigInt
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

final class CovBVmIdentifiedRuntime: RuntimeCodingServiceProtocol, StakingRuntimeIdentifying {
    let chainId: String

    init(chainId: String) {
        self.chainId = chainId
    }

    var snapshot: RuntimeSnapshot? { nil }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        BaseOperation()
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovBVmModelError.unused
    }
}

final class CovBVmPlainRuntime: RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot? { nil }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        BaseOperation()
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovBVmModelError.unused
    }
}

enum CovBVmModelError: Error {
    case unused
    case factory
}

final class CovBVmStakingModelTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let chainFormat = ChainFormat.substrate(42)

    private func address(_ byte: UInt8) throws -> String {
        try AddressFactory.address(for: Data(repeating: byte, count: 32), chainFormat: chainFormat)
    }

    private func electedInfo(nominatorCount: Int, maxRewarded: UInt32?, identity: AccountIdentity? = nil) throws -> ElectedValidatorInfo {
        let nominators = try (0 ..< nominatorCount).map { index in
            NominatorInfo(address: try address(UInt8(10 + index)), stake: Decimal(index + 1))
        }
        return ElectedValidatorInfo(
            address: try address(1),
            nominators: nominators,
            totalStake: 100,
            ownStake: 40,
            comission: 0.05,
            identity: identity,
            stakeReturn: 0.12,
            hasSlashes: true,
            maxNominatorsRewarded: maxRewarded,
            blocked: true,
            elected: false
        )
    }

    // MARK: StakingAlert

    func testStakingAlertActionsIconsAndTexts() {
        let low = LocalizableResource { _ in "bond more" }
        let redeem = LocalizableResource { _ in "redeem now" }
        let alerts: [StakingAlert] = [
            .bondedSetValidators, .nominatorChangeValidators, .nominatorLowStake(low),
            .nominatorAllOversubscribed, .redeemUnbonded(redeem), .waitingNextEra
        ]
        XCTAssertEqual(alerts.map(\.hasAssociatedAction), [true, true, true, true, true, false])
        let warning = R.image.iconWarning()?.pngData()
        XCTAssertEqual(alerts.prefix(5).map { $0.icon?.pngData() }, Array(repeating: warning, count: 5))
        XCTAssertEqual(StakingAlert.waitingNextEra.icon?.pngData(), R.image.iconPending()?.pngData())

        let languages = locale.rLanguages
        XCTAssertEqual(alerts.map { $0.title(for: locale) }, [
            R.string.localizable.stakingSetValidatorsTitle(preferredLanguages: languages),
            R.string.localizable.stakingChangeYourValidators(preferredLanguages: languages),
            R.string.localizable.stakingBondMoreTokens(preferredLanguages: languages),
            R.string.localizable.stakingChangeYourValidators(preferredLanguages: languages),
            R.string.localizable.stakingRedeemUnbondedTokens(preferredLanguages: languages),
            R.string.localizable.stakingNominatorStatusAlertWaitingMessage(preferredLanguages: languages)
        ])
        XCTAssertEqual(alerts.map { $0.description(for: locale) }, [
            R.string.localizable.stakingSetValidatorsMessage(preferredLanguages: languages),
            R.string.localizable.stakingNominatorStatusAlertNoValidators(preferredLanguages: languages),
            "bond more",
            R.string.localizable.stakingYourOversubscribedMessage(preferredLanguages: languages),
            "redeem now",
            R.string.localizable.stakingAlertStartNextEraMessage(preferredLanguages: languages)
        ])
    }

    // MARK: SelectedValidatorInfo

    func testSelectedValidatorInfoDefaultsAndDerivedValues() {
        let plain = SelectedValidatorInfo(address: "plain")
        XCTAssertFalse(plain.oversubscribed)
        XCTAssertFalse(plain.hasIdentity)
        XCTAssertEqual(plain.stakeReturn, 0)
        XCTAssertEqual(plain.totalStake, 0)
        XCTAssertEqual(plain.ownStake, 0)
        XCTAssertFalse(plain.isActive)
        XCTAssertTrue(plain.elected)
        XCTAssertFalse(plain.blocked)
        XCTAssertEqual(plain.commission, 0)

        let stake = ValidatorStakeInfo(
            nominators: [NominatorInfo(address: "a", stake: 10), NominatorInfo(address: "b", stake: 5)],
            totalStake: 40,
            stakeReturn: 0.2,
            maxNominatorsRewarded: 1
        )
        let active = SelectedValidatorInfo(
            address: "active",
            identity: AccountIdentity(name: "Val"),
            stakeInfo: stake,
            myNomination: .active(allocation: ValidatorTokenAllocation(amount: 10, isRewarded: true)),
            commission: 0.1,
            hasSlashes: true,
            blocked: true,
            elected: false
        )
        XCTAssertTrue(active.oversubscribed)
        XCTAssertTrue(active.hasIdentity)
        XCTAssertEqual(active.stakeReturn, 0.2)
        XCTAssertEqual(active.totalStake, 40)
        XCTAssertEqual(active.ownStake, 25)
        XCTAssertTrue(active.isActive)
        XCTAssertFalse(SelectedValidatorInfo(address: "x", myNomination: .elected).isActive)
        XCTAssertFalse(SelectedValidatorInfo(address: "x", myNomination: .unelected).isActive)
        XCTAssertEqual(active, SelectedValidatorInfo(address: "active"))
        XCTAssertNotEqual(active, plain)
    }

    func testValidatorStakeInfoOversubscriptionNeedsLimit() {
        let nominators = [NominatorInfo(address: "a", stake: 1), NominatorInfo(address: "b", stake: 2)]
        XCTAssertFalse(ValidatorStakeInfo(nominators: nominators, totalStake: 3, maxNominatorsRewarded: nil).oversubscribed)
        XCTAssertFalse(ValidatorStakeInfo(nominators: nominators, totalStake: 3, maxNominatorsRewarded: 2).oversubscribed)
        XCTAssertTrue(ValidatorStakeInfo(nominators: nominators, totalStake: 3, maxNominatorsRewarded: 1).oversubscribed)
        XCTAssertEqual(ValidatorStakeInfo(nominators: nominators, totalStake: 3, maxNominatorsRewarded: 1).ownStake, 0)
    }

    // MARK: ElectedValidatorInfo

    func testElectedValidatorInfoFromEraValidatorConvertsAmounts() throws {
        let validator = try AssetHubTestSupport.validator(Data(repeating: 1, count: 32), stake: 3000, own: 1000, commission: 50_000_000)
        let info = try ElectedValidatorInfo(
            validator: validator,
            identity: AccountIdentity(name: "One"),
            stakeReturn: 0.15,
            hasSlashes: false,
            maxNominatorsRewarded: 0,
            chainFormat: chainFormat,
            blocked: false,
            precision: 2,
            elected: true
        )
        XCTAssertEqual(info.address, try address(1))
        XCTAssertEqual(info.totalStake, 30)
        XCTAssertEqual(info.ownStake, 10)
        XCTAssertEqual(info.comission, 0.05)
        XCTAssertEqual(info.nominators, [NominatorInfo(address: try address(3), stake: 2)])
        XCTAssertTrue(info.oversubscribed)
        XCTAssertTrue(info.hasIdentity)
        XCTAssertTrue(info.elected)
        XCTAssertEqual(info.stakeReturn, 0.15)
    }

    func testElectedValidatorInfoHashesByAddress() throws {
        let first = try electedInfo(nominatorCount: 1, maxRewarded: nil)
        let second = try electedInfo(nominatorCount: 3, maxRewarded: 1)
        XCTAssertFalse(first.oversubscribed)
        XCTAssertFalse(first.hasIdentity)
        XCTAssertEqual(Set([first, second]).count, 2)
        var hasher = Hasher()
        first.hash(into: &hasher)
        var expected = Hasher()
        expected.combine(first.address)
        XCTAssertEqual(hasher.finalize(), expected.finalize())
    }

    func testToSelectedMarksActiveNominationAndRewardLimit() throws {
        let info = try electedInfo(nominatorCount: 3, maxRewarded: 1, identity: AccountIdentity(name: "V"))
        let rewarded = info.toSelected(for: try address(10))
        guard case let .active(allocation)? = rewarded.myNomination else { return XCTFail("not active") }
        XCTAssertTrue(allocation.isRewarded)
        XCTAssertEqual(allocation.amount, 1)

        let unrewarded = info.toSelected(for: try address(12))
        guard case let .active(late)? = unrewarded.myNomination else { return XCTFail("not active") }
        XCTAssertFalse(late.isRewarded)
        XCTAssertEqual(late.amount, 3)

        let stranger = info.toSelected(for: try address(99))
        XCTAssertNil(stranger.myNomination)
        XCTAssertNil(info.toSelected(for: nil).myNomination)
        XCTAssertEqual(stranger.address, info.address)
        XCTAssertEqual(stranger.commission, 0.05)
        XCTAssertTrue(stranger.hasSlashes)
        XCTAssertTrue(stranger.blocked)
        XCTAssertFalse(stranger.elected)
        XCTAssertEqual(stranger.identity, info.identity)
        XCTAssertEqual(stranger.stakeInfo?.totalStake, 100)
        XCTAssertEqual(stranger.stakeInfo?.maxNominatorsRewarded, 1)
        XCTAssertTrue(stranger.oversubscribed)

        let unlimited = try electedInfo(nominatorCount: 2, maxRewarded: nil).toSelected(for: try address(11))
        guard case let .active(any)? = unlimited.myNomination else { return XCTFail("not active") }
        XCTAssertTrue(any.isRewarded)
    }

}

final class CovBVmStakingModelSecondTests: XCTestCase {
    private let chainFormat = ChainFormat.substrate(42)

    private func address(_ byte: UInt8) throws -> String {
        try AddressFactory.address(for: Data(repeating: byte, count: 32), chainFormat: chainFormat)
    }

    // MARK: RewardDestination

    func testRewardDestinationFromPayee() throws {
        let stash = StashItem(stash: "stash-address", controller: "controller-address")
        XCTAssertEqual(try RewardDestination(payee: .staked, stashItem: stash, chainFormat: chainFormat), .restake)
        XCTAssertEqual(
            try RewardDestination(payee: .stash, stashItem: stash, chainFormat: chainFormat),
            .payout(account: "stash-address")
        )
        XCTAssertEqual(
            try RewardDestination(payee: .controller, stashItem: stash, chainFormat: chainFormat),
            .payout(account: "controller-address")
        )
        XCTAssertEqual(
            try RewardDestination(payee: .account(Data(repeating: 5, count: 32)), stashItem: stash, chainFormat: chainFormat),
            .payout(account: try address(5))
        )
        XCTAssertEqual(
            try RewardDestination(payee: .address("given"), stashItem: stash, chainFormat: chainFormat),
            .payout(account: "given")
        )
        XCTAssertNotEqual(RewardDestination<AccountAddress>.restake, .payout(account: "given"))
    }

    func testRewardDestinationWithChainAccountMapsAddressAndPayout() throws {
        let account = ChainAccountResponse(
            chainId: "covb",
            accountId: Data(repeating: 6, count: 32),
            publicKey: Data(repeating: 6, count: 32),
            name: "payout",
            cryptoType: .sr25519,
            addressPrefix: 42,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: "wallet"
        )
        let payout = RewardDestination<ChainAccountResponse>.payout(account: account)
        XCTAssertEqual(payout.accountAddress, .payout(account: try address(6)))
        XCTAssertEqual(payout.payoutAccount, account)
        let restake = RewardDestination<ChainAccountResponse>.restake
        XCTAssertEqual(restake.accountAddress, .restake)
        XCTAssertNil(restake.payoutAccount)
    }

    // MARK: AccountIdentity

    func testAccountIdentityReadsIdentityFieldsAndDisplayName() throws {
        func raw(_ text: String) -> [String] { ["Raw", Data(text.utf8).base64EncodedString()] }
        let json: [String: Any] = [
            "additional": [],
            "display": raw("Display"),
            "legal": raw("Legal Name"),
            "web": raw("https://example.invalid"),
            "riot": raw("@riot"),
            "email": raw("a@b.invalid"),
            "image": raw("img"),
            "twitter": raw("@tw")
        ]
        let info = try JSONDecoder().decode(IdentityInfo.self, from: JSONSerialization.data(withJSONObject: json))
        let identity = AccountIdentity(name: "child", parentAddress: "parent-address", parentName: "Parent", identity: info)
        XCTAssertEqual(identity.legal, "Legal Name")
        XCTAssertEqual(identity.web, "https://example.invalid")
        XCTAssertEqual(identity.riot, "@riot")
        XCTAssertEqual(identity.email, "a@b.invalid")
        XCTAssertEqual(identity.image, Data("img".utf8))
        XCTAssertEqual(identity.twitter, "@tw")
        XCTAssertEqual(identity.parentAddress, "parent-address")
        XCTAssertEqual(identity.displayName, "Parent / child")

        let bare = AccountIdentity(name: "solo")
        XCTAssertEqual(bare.displayName, "solo")
        XCTAssertNil(bare.legal)
        XCTAssertNil(bare.image)
    }

    // MARK: StakingRuntimeClock

    func testRuntimeClockKeepsNonAssetHubRuntimes() throws {
        var lookedUp: [String] = []
        let clock = StakingRuntimeClock(
            runtime: { lookedUp.append($0); return nil },
            connection: { lookedUp.append($0); return nil }
        )
        let plain = CovBVmPlainRuntime()
        XCTAssertNil(clock.route(for: plain))
        XCTAssertTrue(try clock.runtime(for: plain) as AnyObject === plain)
        let other = CovBVmIdentifiedRuntime(chainId: "not-an-asset-hub")
        XCTAssertNil(clock.route(for: other))
        let connection = MockConnection()
        XCTAssertTrue(try clock.connection(for: other, stakingConnection: connection) as AnyObject === connection)
        XCTAssertTrue(lookedUp.isEmpty)
    }

    func testRuntimeClockUsesRelayForAssetHubRuntimes() throws {
        let route = AssetHubStakingRoute.routes[0]
        let relayRuntime = CovBVmPlainRuntime()
        let relayConnection = MockConnection()
        let clock = StakingRuntimeClock(
            runtime: { $0 == route.relayChainId ? relayRuntime : nil },
            connection: { $0 == route.relayChainId ? relayConnection : nil }
        )
        let assetHub = CovBVmIdentifiedRuntime(chainId: route.stakingChainId)
        XCTAssertEqual(clock.route(for: assetHub), route)
        XCTAssertTrue(try clock.runtime(for: assetHub) as AnyObject === relayRuntime)
        XCTAssertTrue(try clock.connection(for: assetHub, stakingConnection: MockConnection()) as AnyObject === relayConnection)

        let missing = StakingRuntimeClock(runtime: { _ in nil }, connection: { _ in nil })
        XCTAssertThrowsError(try missing.runtime(for: assetHub)) { error in
            guard case ChainRegistryError.runtimeMetadaUnavailable = error else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try missing.connection(for: assetHub, stakingConnection: MockConnection())) { error in
            guard case ChainRegistryError.connectionUnavailable = error else { return XCTFail("\(error)") }
        }
    }

    // MARK: NetworkStakingInfo

    func testNetworkStakingInfoMinimumStake() {
        let info = NetworkStakingInfo.relaychain(
            baseInfo: BaseStakingInfo(lockUpPeriod: 28, minimalBalance: 5_000_000_000, minStakeAmongActiveNominators: 2_000_000_000),
            relaychainInfo: RelaychainStakingInfo(
                stakingDuration: StakingDuration(session: 1, era: 2, unlocking: 3),
                totalStake: 9,
                activeNominatorsCount: 4
            )
        )
        XCTAssertEqual(info.baseInfo.lockUpPeriod, 28)
        XCTAssertEqual(info.relaychainInfo?.activeNominatorsCount, 4)
        XCTAssertEqual(info.relaychainInfo?.stakingDuration.unlocking, 3)
        XCTAssertEqual(info.calculateMinimumStake(given: nil), 5_000_000_000)
        XCTAssertEqual(info.calculateMinimumStake(given: 7_000_000_000), 7_000_000_000)
        XCTAssertEqual(info.calculateMinimumStake(given: 1), 5_000_000_000)
    }

    // MARK: AssetHubStakingRoute

    func testAssetHubRouteLookupsAndRuntimeTypes() {
        let route = AssetHubStakingRoute.routes[1]
        XCTAssertEqual(AssetHubStakingRoute.staking(on: route.stakingChainId), route)
        XCTAssertNil(AssetHubStakingRoute.staking(on: route.relayChainId))
        XCTAssertEqual(AssetHubStakingRoute.migrating(route.relayChainId), route)
        XCTAssertNil(AssetHubStakingRoute.migrating(route.stakingChainId))
        let existing = Data("existing".utf8)
        XCTAssertEqual(AssetHubStakingRoute.runtimeTypes(for: "other", existing: existing), existing)
        XCTAssertNil(AssetHubStakingRoute.runtimeTypes(for: "other", existing: nil))
        let generated = AssetHubStakingRoute.runtimeTypes(for: route.stakingChainId, existing: nil)
        XCTAssertEqual(generated.flatMap { String(data: $0, encoding: .utf8) }, "{\"runtime_id\":0,\"versioning\":[],\"types\":{}}")
    }

    func testAssetHubRouteSelectedAssetAndOffersStaking() {
        let route = AssetHubStakingRoute.routes[2]
        let native = AssetHubTestSupport.makeAsset(
            chainId: route.stakingChainId, parentId: route.relayChainId, assetId: route.nativeAssetId,
            staking: .assetHub, type: .normal
        )
        XCTAssertTrue(AssetHubStakingRoute.offersStaking(native.asset, on: native.chain))
        let wrongParent = AssetHubTestSupport.makeAsset(
            chainId: route.stakingChainId, parentId: "elsewhere", assetId: route.nativeAssetId, staking: .assetHub, type: .normal
        )
        XCTAssertFalse(AssetHubStakingRoute.offersStaking(wrongParent.asset, on: wrongParent.chain))
        let plain = AssetHubTestSupport.makeAsset(chainId: "plain-chain", staking: .relayChain)
        XCTAssertTrue(AssetHubStakingRoute.offersStaking(plain.asset, on: plain.chain))
        let misdeclared = AssetHubTestSupport.makeAsset(chainId: "plain-chain", staking: .assetHub)
        XCTAssertFalse(AssetHubStakingRoute.offersStaking(misdeclared.asset, on: misdeclared.chain))

        let chains = [native.chain, plain.chain]
        let fromRelay = AssetHubStakingRoute.selectedAsset(
            ChainAssetId(chainId: route.relayChainId, assetId: route.nativeAssetId), in: chains
        )
        XCTAssertEqual(fromRelay?.chain.chainId, route.stakingChainId)
        XCTAssertNil(AssetHubStakingRoute.selectedAsset(ChainAssetId(chainId: route.relayChainId, assetId: "other"), in: chains))
        XCTAssertEqual(
            AssetHubStakingRoute.selectedAsset(ChainAssetId(chainId: "plain-chain", assetId: "0"), in: chains)?.asset.id,
            "0"
        )
        XCTAssertNil(AssetHubStakingRoute.selectedAsset(ChainAssetId(chainId: "missing", assetId: "0"), in: chains))
    }

    // MARK: StakingSharedState

    func testSharedStateReplacesServices() {
        let settings = StakingAssetSettings(
            storageFacade: SubstrateStorageTestFacade(),
            settings: InMemorySettingsManager(),
            operationQueue: OperationQueue(),
            wallet: AccountGenerator.generateMetaAccount()
        )
        let firstEra = EraValidatorServiceStub(info: EraStakersInfo(activeEra: 1, validators: []))
        let firstReward = RewardCalculatorServiceStub(engine: CovBVmRewardEngine())
        let subscription = StakingLocalSubscriptionFactoryStub()
        let state = StakingSharedState(
            settings: settings,
            eraValidatorService: firstEra,
            rewardCalculationService: firstReward,
            relaychainStakingLocalSubscriptionFactory: subscription
        )
        XCTAssertTrue(state.settings === settings)
        XCTAssertTrue(state.eraValidatorService as AnyObject === firstEra)
        XCTAssertTrue(state.rewardCalculationService as AnyObject === firstReward)
        XCTAssertTrue(state.relaychainStakingLocalSubscriptionFactory as AnyObject === subscription)

        let secondEra = EraValidatorServiceStub(info: EraStakersInfo(activeEra: 2, validators: []))
        let secondReward = RewardCalculatorServiceStub(engine: CovBVmRewardEngine())
        state.replaceEraValidatorService(secondEra)
        state.replaceRewardCalculatorService(secondReward)
        XCTAssertTrue(state.eraValidatorService as AnyObject === secondEra)
        XCTAssertTrue(state.rewardCalculationService as AnyObject === secondReward)
    }

    // MARK: ChainStakingSettings

    func testRelaychainAndSoraSettingsShapeCallArguments() {
        let accountId = Data(repeating: 8, count: 32)
        let relay = DefaultRelaychainChainStakingSettings()
        let sora = SoraChainStakingSettings()
        XCTAssertNil(relay.rewardAssetName)
        XCTAssertEqual(sora.rewardAssetName, "val")
        XCTAssertEqual(relay.rewardDestinationArg(accountId: accountId), .account(accountId))
        XCTAssertEqual(sora.rewardDestinationArg(accountId: accountId), .account(accountId))
        guard case let .accoundId(relayId) = relay.multiAddress(accountId: accountId) else { return XCTFail("relay address") }
        XCTAssertEqual(relayId, accountId)
        guard case let .accountTo(soraId) = sora.multiAddress(accountId: accountId) else { return XCTFail("sora address") }
        XCTAssertEqual(soraId, accountId)
    }

    func testSettingsQueriesForwardFactoryFailures() {
        let settingsList: [ChainStakingSettings] = [DefaultRelaychainChainStakingSettings(), SoraChainStakingSettings()]
        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
        for settings in settingsList {
            let wrapper: CompoundOperationWrapper<[StorageResponse<ValidatorPrefs>]> = settings.queryItems(
                engine: MockConnection(),
                keyParams: { [Data(repeating: 1, count: 32)] },
                factory: { throw CovBVmModelError.factory },
                storagePath: .validatorPrefs,
                using: requestFactory
            )
            OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
            assertFactoryFailure(wrapper.targetOperation.result)

            let operation = covBVmAwaitResult(settings.queryItems(
                engine: MockConnection(),
                keyParams: { [Data(repeating: 1, count: 32)] },
                factory: { throw CovBVmModelError.factory },
                storagePath: .validatorPrefs,
                using: AsyncStorageRequestDefault()
            ), ValidatorPrefs.self)
            assertFactoryFailure(operation)
        }
    }

    private func covBVmAwaitResult<T>(
        _ operation: BaseOperation<[StorageResponse<T>]>,
        _: T.Type
    ) -> Result<[StorageResponse<T>], Error>? {
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return operation.result
    }

    private func assertFactoryFailure<T>(_ result: Result<T, Error>?, file: StaticString = #filePath, line: UInt = #line) {
        guard case let .failure(error)? = result else {
            return XCTFail("expected failure, got \(String(describing: result))", file: file, line: line)
        }
        guard case CovBVmModelError.factory = error else {
            return XCTFail("unexpected \(error)", file: file, line: line)
        }
    }
}

final class CovBVmRewardEngine: RewardCalculatorEngineProtocol {
    var rewardAssetRate: Decimal { 1 }

    func calculateEarnings(amount _: Decimal, validatorAccountId _: AccountId, isCompound _: Bool, period _: CalculationPeriod) throws -> Decimal { 0 }
    func calculateMaxEarnings(amount _: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { 0 }
    func calculateAvgEarnings(amount _: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { 0 }
    func calculatorReturn(isCompound _: Bool, period _: CalculationPeriod, type _: RewardReturnType) -> Decimal { 0 }
    func maxEarningsTitle(locale _: Locale) -> String { "max" }
    func avgEarningTitle(locale _: Locale) -> String { "avg" }
}
