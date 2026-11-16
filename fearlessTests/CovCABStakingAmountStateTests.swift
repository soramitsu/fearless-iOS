import XCTest
import SSFModels
import SoraFoundation
import BigInt
import RobinHood
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

enum CovCABSAError: Error {
    case unavailable
}

final class CovCABSARuntime: RuntimeProviderProtocol {
    var snapshot: RuntimeSnapshot? { nil }
    var runtimeSpecVersion: RuntimeSpecVersion { .defaultVersion }

    func setup() {}
    func cleanup() {}
    func setupHot() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        throw CovCABSAError.unavailable
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let operation = BaseOperation<RuntimeCoderFactoryProtocol>()
        operation.result = .failure(CovCABSAError.unavailable)
        return operation
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovCABSAError.unavailable
    }
}

final class CovCABSAListener: StakingAmountModelStateListener {
    private(set) var changes = 0

    func modelStateDidChanged(viewModelState _: StakingAmountViewModelState) {
        changes += 1
    }
}

final class CovCABSAPresentable: StakingErrorPresentable, SheetAlertPresentable, ErrorPresentable {
    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }
}

final class CovCABSACalculator: RewardCalculatorEngineProtocol {
    var rewardAssetRate: Decimal = 1

    func calculateEarnings(amount _: Decimal, validatorAccountId _: AccountId, isCompound _: Bool, period _: CalculationPeriod) throws -> Decimal {
        0
    }

    func calculateMaxEarnings(amount _: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { 0 }
    func calculateAvgEarnings(amount _: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { 0 }

    func calculatorReturn(isCompound: Bool, period _: CalculationPeriod, type _: RewardReturnType) -> Decimal {
        isCompound ? 0.2 : 0.1
    }

    func maxEarningsTitle(locale _: Locale) -> String { "max" }
    func avgEarningTitle(locale _: Locale) -> String { "avg" }
}

enum CovCABSAFixtures {
    static func soraChain() -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: Data(repeating: 9, count: 32).toHex(),
            paraId: nil,
            name: "SORA Mainnet",
            xcm: nil,
            nodes: Set([ChainNodeModel(url: Constants.dummyURL, name: "node", apikey: nil)]),
            addressPrefix: 69,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    static func networkInfo(minimalBalance: BigUInt) -> NetworkStakingInfo {
        .relaychain(
            baseInfo: BaseStakingInfo(lockUpPeriod: 28, minimalBalance: minimalBalance, minStakeAmongActiveNominators: 0),
            relaychainInfo: RelaychainStakingInfo(
                stakingDuration: StakingDuration(session: 3600, era: 86400, unlocking: 86400 * 28),
                totalStake: 1000,
                activeNominatorsCount: 10
            )
        )
    }
}

final class CovCABStakingAmountStateTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var listener: CovCABSAListener!

    override func setUp() {
        super.setUp()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        chainAsset = ChainAsset(chain: chain, asset: asset)
        wallet = AccountGenerator.generateMetaAccount()
        listener = CovCABSAListener()
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        listener = nil
        super.tearDown()
    }

    private func makeState(amount: Decimal?, chainAsset: ChainAsset? = nil) -> StakingAmountRelaychainViewModelState {
        let state = StakingAmountRelaychainViewModelState(
            dataValidatingFactory: StakingDataValidatingFactory(presentable: CovCABSAPresentable()),
            wallet: wallet,
            chainAsset: chainAsset ?? self.chainAsset,
            amount: amount,
            callFactory: SubstrateCallFactoryDefault(runtimeService: CovCABSARuntime()),
            rewardChainAsset: nil
        )
        state.setStateListener(listener)
        return state
    }

    func testInitialAmountBuildsBondingWithRestake() throws {
        let state = makeState(amount: 5)

        XCTAssertEqual(state.amount, 5)
        XCTAssertNotNil(state.payoutAccount)
        let bonding = try XCTUnwrap(state.bonding)
        XCTAssertEqual(bonding.amount, 5)
        guard case .restake = bonding.rewardDestination else {
            return XCTFail("expected restake")
        }
        XCTAssertEqual(state.learnMoreUrl, ApplicationConfig.shared.learnPayoutURL)
        XCTAssertFalse(state.continueAvailable)
        XCTAssertNil(state.rewardChainAsset)
        XCTAssertTrue(state.stateListener === listener)
    }

    func testWithoutAmountThereIsNoBonding() {
        let state = makeState(amount: nil)

        XCTAssertNil(state.amount)
        XCTAssertNil(state.bonding)
    }

    func testSoraChainDefaultsToPayout() {
        let sora = CovCABSAFixtures.soraChain()
        let asset = ChainModelGenerator.generateAssetWithId("xor", symbol: "XOR", assetPresicion: 18)
        let state = makeState(amount: 1, chainAsset: ChainAsset(chain: sora, asset: asset))

        guard case .payout = state.rewardDestination else {
            return XCTFail("expected payout on SORA")
        }
    }

    func testStrategyOutputsFillStateAndEnableContinue() {
        let state = makeState(amount: nil)

        state.didReceive(minimalBalance: BigUInt(10_000_000_000))
        XCTAssertEqual(state.minimalBalance, 1)
        state.didReceive(minimalBalance: nil)
        XCTAssertEqual(listener.changes, 1)

        state.didReceive(minimumBond: BigUInt(20_000_000_000))
        XCTAssertEqual(state.minimumBond, 2)
        state.didReceive(minimumBond: nil)
        XCTAssertEqual(state.minimumBond, 0)

        state.didReceive(counterForNominators: 5)
        XCTAssertEqual(state.counterForNominators, 5)
        state.didReceive(maxNominatorsCount: 50)
        XCTAssertEqual(state.maxNominatorsCount, 50)
        state.didReceive(maxNominations: 16)
        XCTAssertEqual(state.maxNominations, 16)

        state.didReceive(paymentInfo: RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000)))
        XCTAssertEqual(state.fee, Decimal(string: "0.1"))

        state.didReceive(networkStakingInfo: CovCABSAFixtures.networkInfo(minimalBalance: BigUInt(10_000_000_000)))
        XCTAssertEqual(state.minStake, 1)

        state.didReceive(error: CovCABSAError.unavailable)
        state.didReceive(networkStakingInfoError: CovCABSAError.unavailable)
        XCTAssertFalse(state.continueAvailable)

        state.updateBalance(Decimal(string: "10.1"))
        XCTAssertTrue(state.continueAvailable)
        XCTAssertEqual(listener.changes, 8)

        state.applyLocalization()
        XCTAssertEqual(listener.changes, 9)
    }

    func testAmountFollowsPercentageAndAbsoluteInput() {
        let state = makeState(amount: nil)
        state.didReceive(minimalBalance: BigUInt(10_000_000_000))
        state.didReceive(paymentInfo: RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000)))
        state.updateBalance(Decimal(string: "10.1"))

        state.selectAmountPercentage(0.5)
        XCTAssertEqual(state.amount, Decimal(string: "4.5"))

        state.updateAmount(3)
        XCTAssertEqual(state.amount, 3)
        XCTAssertEqual(state.bonding?.amount, 3)
    }

    func testRewardDestinationSelection() throws {
        let state = makeState(amount: 1)
        let otherAccount = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: chainAsset.chain.accountRequest()))

        state.selectPayoutDestination()
        guard case let .payout(account) = state.rewardDestination else {
            return XCTFail("expected payout")
        }
        XCTAssertEqual(account, state.payoutAccount)

        state.selectRestakeDestination()
        guard case .restake = state.rewardDestination else {
            return XCTFail("expected restake")
        }

        state.selectPayoutAccount(payoutAccount: nil)
        XCTAssertEqual(listener.changes, 2)

        state.selectPayoutAccount(payoutAccount: otherAccount)
        XCTAssertEqual(state.payoutAccount, otherAccount)
        XCTAssertEqual(listener.changes, 3)
        guard case let .payout(selected) = state.rewardDestination else {
            return XCTFail("expected payout to selected account")
        }
        XCTAssertEqual(selected, otherAccount)
    }

    func testValidatorsBlockLowAmountAndPassValidAmount() {
        let state = makeState(amount: Decimal(string: "0.5"))
        state.didReceive(minimalBalance: BigUInt(10_000_000_000))
        state.didReceive(minimumBond: BigUInt(20_000_000_000))
        state.didReceive(networkStakingInfo: CovCABSAFixtures.networkInfo(minimalBalance: BigUInt(10_000_000_000)))
        state.updateBalance(100)

        let locale = Locale(identifier: "en")
        XCTAssertEqual(state.validators(using: locale).count, 3)

        var completions = 0
        DataValidationRunner(validators: state.validators(using: locale)).runValidation { completions += 1 }
        XCTAssertEqual(completions, 0)

        state.updateAmount(5)
        state.didReceive(counterForNominators: 1)
        state.didReceive(maxNominatorsCount: 10)
        DataValidationRunner(validators: state.validators(using: locale)).runValidation { completions += 1 }
        XCTAssertEqual(completions, 1)
    }

    func testFeeClosureReturnsBuilderWhenNothingToAdd() throws {
        let state = makeState(amount: nil)
        let builder = ExtrinsicBuilder(specVersion: 1, transactionVersion: 1, genesisHash: "0x00")

        let result = try state.feeExtrinsicBuilderClosure(builder)

        XCTAssertTrue(result === builder)
    }

    func testFeeClosureAddsNominateCall() throws {
        let state = makeState(amount: nil)
        state.didReceive(maxNominations: 2)
        let builder = ExtrinsicBuilder(specVersion: 1, transactionVersion: 1, genesisHash: "0x00")

        let result = try state.feeExtrinsicBuilderClosure(builder)

        XCTAssertTrue(result === builder)
        XCTAssertEqual(state.maxNominations, 2)
    }

    func testFeeClosureBondFailsWithoutMetadata() {
        let state = makeState(amount: 2)
        let builder = ExtrinsicBuilder(specVersion: 1, transactionVersion: 1, genesisHash: "0x00")

        XCTAssertThrowsError(try state.feeExtrinsicBuilderClosure(builder))
    }
}

final class CovCABStakingAmountViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var balanceFactory: BalanceViewModelFactory!
    private var rewardFactory: RewardDestinationViewModelFactory!
    private var factory: StakingAmountRelaychainViewModelFactory!

    override func setUp() {
        super.setUp()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        chainAsset = ChainAsset(chain: chain, asset: asset)
        wallet = AccountGenerator.generateMetaAccount()
        balanceFactory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)
        rewardFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceFactory,
            iconGenerator: UniversalIconGenerator(),
            chainAsset: chainAsset
        )
        factory = StakingAmountRelaychainViewModelFactory(
            balanceViewModelFactory: balanceFactory,
            rewardDestViewModelFactory: rewardFactory,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    override func tearDown() {
        factory = nil
        rewardFactory = nil
        balanceFactory = nil
        wallet = nil
        chainAsset = nil
        super.tearDown()
    }

    private func makeState(amount: Decimal?) -> StakingAmountRelaychainViewModelState {
        StakingAmountRelaychainViewModelState(
            dataValidatingFactory: StakingDataValidatingFactory(presentable: CovCABSAPresentable()),
            wallet: wallet,
            chainAsset: chainAsset,
            amount: amount,
            callFactory: SubstrateCallFactoryDefault(runtimeService: CovCABSARuntime()),
            rewardChainAsset: nil
        )
    }

    func testBuildViewModelWithoutFeeOrCalculator() throws {
        let state = makeState(amount: 2)

        let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state, priceData: nil, calculator: nil))

        XCTAssertNil(viewModel.feeViewModel)
        XCTAssertNil(viewModel.assetViewModel)
        XCTAssertNil(viewModel.inputViewModel)
        XCTAssertFalse(viewModel.continueAvailable)
        let destination = try XCTUnwrap(viewModel.rewardDestinationViewModel).value(for: locale)
        XCTAssertNil(destination.rewardViewModel)
        guard case .restake = destination.type else {
            return XCTFail("expected restake")
        }
    }

    func testBuildViewModelWithFeeAndCalculator() throws {
        let state = makeState(amount: 10)
        state.didReceive(paymentInfo: RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000)))
        let price = PriceData(currencyId: "usd", priceId: "dot", price: "5", fiatDayChange: nil, coingeckoPriceId: nil)

        let viewModel = try XCTUnwrap(
            factory.buildViewModel(viewModelState: state, priceData: price, calculator: CovCABSACalculator())
        )

        let fee = try XCTUnwrap(viewModel.feeViewModel).value(for: locale)
        let expectedFee = balanceFactory.balanceFromPrice(Decimal(string: "0.1") ?? 0, priceData: price, usageCase: .detailsCrypto)
        XCTAssertEqual(fee.amount, expectedFee.value(for: locale).amount)
        XCTAssertNotNil(fee.price)

        let reward = try XCTUnwrap(try XCTUnwrap(viewModel.rewardDestinationViewModel).value(for: locale).rewardViewModel)
        XCTAssertEqual(reward.restakeAmount, balanceFactory.balanceFromPrice(2, priceData: price, usageCase: .listCrypto).value(for: locale).amount)
        XCTAssertEqual(reward.payoutAmount, balanceFactory.balanceFromPrice(1, priceData: price, usageCase: .listCrypto).value(for: locale).amount)
        XCTAssertFalse(reward.restakePercentage.isEmpty)
        XCTAssertFalse(reward.payoutPercentage.isEmpty)
        XCTAssertFalse(reward.restakePrice.isEmpty)
        XCTAssertTrue(reward.restakeAvailable)
    }

    func testPayoutDestinationUsesAccountName() throws {
        let state = makeState(amount: nil)
        state.selectPayoutDestination()
        let account = try XCTUnwrap(state.payoutAccount)

        let resource = try XCTUnwrap(
            try factory.buildSelectRewardDestinationViewModel(viewModelState: state, priceData: nil, calculator: CovCABSACalculator())
        )

        let viewModel = resource.value(for: locale)
        guard case let .payout(_, title, address) = viewModel.type else {
            return XCTFail("expected payout")
        }
        XCTAssertEqual(title, account.name)
        XCTAssertEqual(address, account.toAddress())
        XCTAssertNotNil(viewModel.rewardViewModel)
    }

    func testFactoryIgnoresForeignStates() throws {
        let foreign = CovCABSAForeignState()

        XCTAssertNil(factory.buildViewModel(viewModelState: foreign, priceData: nil, calculator: nil))
        XCTAssertNil(try factory.buildSelectRewardDestinationViewModel(viewModelState: foreign, priceData: nil, calculator: nil))
    }

    func testRewardDestinationFactoryEmptyAndSoraVariants() throws {
        let restake = rewardFactory.createRestake(from: nil, priceData: nil).value(for: locale)
        XCTAssertNil(restake.rewardViewModel)

        let address = try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress())
        let payout = try rewardFactory.createPayout(from: nil, priceData: nil, address: address, title: "Name").value(for: locale)
        guard case let .payout(icon, title, payoutAddress) = payout.type else {
            return XCTFail("expected payout")
        }
        XCTAssertNotNil(icon)
        XCTAssertEqual(title, "Name")
        XCTAssertEqual(payoutAddress, address)

        let soraAsset = ChainModelGenerator.generateAssetWithId("xor", symbol: "XOR", assetPresicion: 18)
        let soraFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceFactory,
            iconGenerator: UniversalIconGenerator(),
            chainAsset: ChainAsset(chain: CovCABSAFixtures.soraChain(), asset: soraAsset)
        )
        let reward = CalculatedReward(restakeReturn: 1, restakeReturnPercentage: 0.1, payoutReturn: 1, payoutReturnPercentage: 0.1)
        let soraViewModel = soraFactory.createRestake(from: reward, priceData: nil).value(for: locale)
        XCTAssertEqual(soraViewModel.rewardViewModel?.restakeAvailable, false)
        XCTAssertEqual(soraViewModel.rewardViewModel?.restakePrice, "")
    }
}

final class CovCABSAForeignState: StakingAmountViewModelState {
    var stateListener: StakingAmountModelStateListener?
    var feeExtrinsicBuilderClosure: ExtrinsicBuilderClosure { { $0 } }
    var amount: Decimal? { nil }
    var fee: Decimal?
    var bonding: InitiatedBonding? { nil }
    var payoutAccount: fearless.ChainAccountResponse? { nil }
    var learnMoreUrl: URL? { nil }
    var continueAvailable: Bool { false }
    var rewardChainAsset: ChainAsset? { nil }

    func setStateListener(_ stateListener: StakingAmountModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using _: Locale) -> [DataValidating] { [] }
    func updateBalance(_: Decimal?) {}
}
