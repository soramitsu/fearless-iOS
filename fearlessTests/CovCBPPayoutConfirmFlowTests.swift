import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import IrohaCrypto
import SSFRuntimeCodingService
import SoraFoundation
@testable import fearless

final class CovCBPPCFRuntimeStub: SSFRuntimeCodingService.RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    var snapshot: RuntimeSnapshot?

    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot { throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable }
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> { BaseOperation() }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol { throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable }
}

final class CovCBPPCFListener: StakingPayoutConfirmationModelStateListener {
    var events: [String] = []
    var hashes: [[String]] = []

    func didReceiveError(error _: Error) { events.append("error") }
    func provideFee() { events.append("fee") }
    func provideViewModel() { events.append("viewModel") }
    func didStartPayout() { events.append("start") }
    func didCompletePayout(txHashes: [String]) { hashes.append(txHashes); events.append("completeHashes") }
    func didCompletePayout(result _: SubmitExtrinsicResult) { events.append("completeResult") }
    func didFailPayout(error _: Error) { events.append("fail") }
}

final class CovCBPPCFPresentableDouble: StakingErrorPresentable, SheetAlertPresentable, ErrorPresentable {
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
    func dismiss(view _: ControllerBackedProtocol?) {}
}

final class CovCBPPayoutConfirmFlowTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let languages = ["en"]

    private lazy var utilityAsset = AssetModel(
        id: "dot",
        name: "DOT",
        symbol: "dot",
        precision: 10,
        icon: nil,
        currencyId: nil,
        existentialDeposit: nil,
        color: nil,
        isUtility: true,
        isNative: true,
        staking: nil,
        purchaseProviders: nil,
        type: nil,
        ethereumType: nil,
        priceProvider: nil,
        coingeckoPriceId: nil
    )

    private lazy var chain: ChainModel = {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        chain.assets = [utilityAsset]
        return chain
    }()

    private lazy var chainAsset = ChainAsset(chain: chain, asset: utilityAsset)
    private lazy var wallet = AccountGenerator.generateMetaAccount()
    private lazy var balanceFactory = BalanceViewModelFactory(targetAssetInfo: utilityAsset.displayInfo, selectedMetaAccount: wallet)
    private let presentable = CovCBPPCFPresentableDouble()

    private func makeValidatingFactory() -> StakingDataValidatingFactory {
        StakingDataValidatingFactory(presentable: presentable)
    }

    private func makeCallFactory() -> SubstrateCallFactoryDefault {
        SubstrateCallFactoryDefault(runtimeService: CovCBPPCFRuntimeStub())
    }

    private func makeRelayState(chainAsset: ChainAsset? = nil) -> StakingPayoutConfirmationRelaychainViewModelState {
        StakingPayoutConfirmationRelaychainViewModelState(
            chainAsset: chainAsset ?? self.chainAsset,
            wallet: wallet,
            logger: nil,
            dataValidatingFactory: makeValidatingFactory(),
            callFactory: makeCallFactory()
        )
    }

    private func makePoolState() -> StakingPayoutConfirmationPoolViewModelState {
        StakingPayoutConfirmationPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            logger: nil,
            dataValidatingFactory: makeValidatingFactory(),
            callFactory: makeCallFactory()
        )
    }

    private func account() throws -> fearless.ChainAccountResponse {
        try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
    }

    private func accountInfo(free: BigUInt) -> AccountInfo {
        AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: free, reserved: 0, frozen: 0))
    }

    private func runValidators(_ validators: [DataValidating]) -> Bool {
        var passed = false
        DataValidationRunner(validators: validators).runValidation { passed = true }
        return passed
    }

    // MARK: - Relaychain view model factory

    func testRelaychainFactoryBuildsAccountDestinationAndRewardRows() throws {
        let factory = StakingPayoutConfirmationRelaychainViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceFactory,
            iconGenerator: UniversalIconGenerator()
        )
        let state = makeRelayState()
        state.didRecieve(account: try account(), rewardAmount: 2)
        let payoutAddress = try SS58AddressFactory().address(fromAccountId: Data(repeating: 3, count: 32), type: 0)
        state.didReceiveRewardDestination(result: .success(.payout(account: DisplayAddress(address: payoutAddress, username: ""))))

        let rows = factory.createPayoutConfirmViewModel(viewModelState: state, priceData: nil).map { $0.value(for: locale) }
        XCTAssertEqual(rows.count, 3)

        guard case let .accountInfo(accountRow) = rows[0] else { return XCTFail("account row expected") }
        XCTAssertEqual(accountRow.title, R.string.localizable.commonAccount(preferredLanguages: languages))
        XCTAssertEqual(accountRow.name, wallet.name)
        XCTAssertEqual(accountRow.address, try account().toAddress())

        guard case let .accountInfo(destinationRow) = rows[1] else { return XCTFail("destination row expected") }
        XCTAssertEqual(destinationRow.title, R.string.localizable.stakingRewardsDestinationTitle(preferredLanguages: languages))
        XCTAssertEqual(destinationRow.name, payoutAddress)
        XCTAssertNotNil(destinationRow.icon)

        guard case let .rewardAmountViewModel(reward) = rows[2] else { return XCTFail("reward row expected") }
        XCTAssertEqual(reward.title, R.string.localizable.stakingReward(preferredLanguages: languages))
        XCTAssertEqual(reward.tokenAmountText, balanceFactory.balanceFromPrice(2, priceData: nil, usageCase: .listCrypto).value(for: locale).amount)

        XCTAssertNil(factory.createSinglePayoutConfirmationViewModel(viewModelState: state, priceData: nil))
    }

    func testRelaychainFactoryRestakeNamedDestinationAndForeignState() throws {
        let factory = StakingPayoutConfirmationRelaychainViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceFactory,
            iconGenerator: UniversalIconGenerator()
        )
        let state = makeRelayState()

        state.didReceiveRewardDestination(result: .success(.restake))
        var rows = factory.createPayoutConfirmViewModel(viewModelState: state, priceData: nil).map { $0.value(for: locale) }
        XCTAssertEqual(rows.count, 2)
        guard case let .restakeDestination(restake) = rows[0] else { return XCTFail("restake row expected") }
        XCTAssertEqual(restake.valueText, R.string.localizable.stakingRestakeTitle(preferredLanguages: languages))

        state.didReceiveRewardDestination(result: .success(.payout(account: DisplayAddress(address: "5Named", username: "Named"))))
        rows = factory.createPayoutConfirmViewModel(viewModelState: state, priceData: nil).map { $0.value(for: locale) }
        guard case let .accountInfo(named) = rows[0] else { return XCTFail("named row expected") }
        XCTAssertEqual(named.name, "Named")

        XCTAssertTrue(factory.createPayoutConfirmViewModel(viewModelState: makePoolState(), priceData: nil).isEmpty)
    }

    // MARK: - Pool view model factory

    func testPoolFactoryBuildsSingleViewModel() throws {
        let factory = StakingPayoutConfirmationPoolViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceFactory,
            iconGenerator: UniversalIconGenerator()
        )
        let state = makePoolState()
        state.didRecieve(account: try account(), rewardAmount: 4)

        XCTAssertTrue(factory.createPayoutConfirmViewModel(viewModelState: state, priceData: nil).isEmpty)

        let single = try XCTUnwrap(factory.createSinglePayoutConfirmationViewModel(viewModelState: state, priceData: nil))
        let amountString = try XCTUnwrap(
            AssetBalanceFormatterFactory().createTokenFormatter(for: utilityAsset.displayInfo, usageCase: .detailsCrypto)
                .value(for: locale).stringFromDecimal(4)
        )
        XCTAssertEqual(single.senderAddress, try account().toAddress())
        XCTAssertEqual(single.senderName, wallet.name)
        XCTAssertNil(single.senderIcon)
        XCTAssertEqual(single.amountString.value(for: locale), amountString)

        let stake = try XCTUnwrap(single.amount).value(for: locale)
        XCTAssertTrue(stake.amountTitle.string.contains(amountString))
        XCTAssertNotNil(stake.iconViewModel)

        XCTAssertNil(factory.createSinglePayoutConfirmationViewModel(viewModelState: makeRelayState(), priceData: nil))
    }

    // MARK: - Relaychain state

    func testRelaychainStateForwardsEventsAndStoresValues() throws {
        let state = makeRelayState()
        let listener = CovCBPPCFListener()
        state.setStateListener(listener)

        state.didReceiveFee(result: .success(0.1))
        state.didReceiveFee(result: .failure(CommonError.undefined))
        XCTAssertEqual(state.fee, 0.1)

        state.didRecieve(account: try account(), rewardAmount: 3)
        XCTAssertEqual(state.rewardAmount, 3)
        XCTAssertNotNil(state.account)

        state.didReceiveRewardDestination(result: .failure(CommonError.undefined))
        XCTAssertNil(state.rewardDestination)

        state.didStartPayout()
        state.didCompletePayout(txHashes: ["0x1"])
        state.didFailPayout(error: CommonError.undefined)

        XCTAssertEqual(listener.events, ["fee", "viewModel", "start", "completeHashes", "fail"])
        XCTAssertEqual(listener.hashes, [["0x1"]])
        XCTAssertNil(state.builderClosure)
    }

    func testRelaychainStateValidatorsUseUtilityBalance() throws {
        let state = makeRelayState()
        let listener = CovCBPPCFListener()
        state.setStateListener(listener)

        XCTAssertEqual(state.validators(using: locale).count, 3)
        XCTAssertFalse(runValidators(state.validators(using: locale)))
        XCTAssertEqual(listener.events, ["fee"])

        state.didRecieve(account: try account(), rewardAmount: 5)
        state.didReceiveFee(result: .success(1))

        let otherAsset = ChainModelGenerator.generateAssetWithId("other", symbol: "OTH", assetPresicion: 10)
        state.didReceiveAccountInfo(result: .success(accountInfo(free: 100_000_000_000)), chainAsset: ChainAsset(chain: chain, asset: otherAsset))
        XCTAssertFalse(runValidators(state.validators(using: locale)))

        state.didReceiveAccountInfo(result: .success(accountInfo(free: 100_000_000_000)), chainAsset: chainAsset)
        XCTAssertTrue(runValidators(state.validators(using: locale)))

        state.didReceiveAccountInfo(result: .success(nil), chainAsset: chainAsset)
        XCTAssertFalse(runValidators(state.validators(using: locale)))

        state.didReceiveAccountInfo(result: .failure(CommonError.undefined), chainAsset: chainAsset)
        XCTAssertFalse(runValidators(state.validators(using: locale)))
    }

    func testRelaychainStateRewardInForeignFeeAssetWithoutPrices() throws {
        let rewardAsset = ChainModelGenerator.generateAssetWithId("reward", symbol: "RWD", assetPresicion: 10)
        let state = makeRelayState(chainAsset: ChainAsset(chain: chain, asset: rewardAsset))
        state.didRecieve(account: try account(), rewardAmount: 5)
        state.didReceiveFee(result: .success(1))
        state.didReceiveAccountInfo(result: .success(accountInfo(free: 100_000_000_000)), chainAsset: chainAsset)

        XCTAssertFalse(runValidators(state.validators(using: locale)))
    }

    // MARK: - Pool state

    func testPoolStateFeeBalanceAndValidators() throws {
        let state = makePoolState()
        let listener = CovCBPPCFListener()
        state.setStateListener(listener)

        XCTAssertNotNil(state.builderClosure)
        XCTAssertFalse(runValidators(state.validators(using: locale)))

        state.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        XCTAssertEqual(state.fee, 1)
        state.didReceiveFee(result: .failure(CommonError.undefined))
        XCTAssertEqual(state.fee, 1)

        state.didRecieve(account: try account(), rewardAmount: 2)
        state.didReceiveAccountInfo(result: .success(accountInfo(free: 50_000_000_000)))
        XCTAssertTrue(runValidators(state.validators(using: locale)))

        state.didReceiveAccountInfo(result: .success(nil))
        XCTAssertFalse(runValidators(state.validators(using: locale)))
        state.didReceiveAccountInfo(result: .failure(CommonError.undefined))

        state.didStartPayout()
        state.didCompletePayout(result: .success("0xabc"))
        state.didFailPayout(error: CommonError.undefined)

        XCTAssertEqual(listener.events, ["fee", "fee", "viewModel", "start", "completeResult", "fail"])
        XCTAssertEqual(state.rewardAmount, 2)
        XCTAssertNil(state.rewardDestination)
    }
}
