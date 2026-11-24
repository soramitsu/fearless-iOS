import BigInt
import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

/// The outputs every confirm view-model state shares, so one test can drive all four flows.
protocol CovAConfirmStateOutputs: AnyObject, SelectValidatorsConfirmViewModelState {
    var confirmationModel: SelectValidatorsConfirmRelaychainModel? { get }
    var minNominatorBond: Decimal? { get }
    var counterForNominators: UInt32? { get }
    var maxNominatorsCount: UInt32? { get }
    var stakingDuration: StakingDuration? { get }

    func didSetup()
    func didReceiveMinBond(result: Result<BigUInt?, Error>)
    func didReceiveCounterForNominators(result: Result<UInt32?, Error>)
    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>)
    func didReceiveStakingDuration(result: Result<StakingDuration, Error>)
    func didStartNomination()
    func didCompleteNomination(txHash: String)
    func didFailNomination(error: Error)
    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceive(feeError: Error)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
}

extension SelectValidatorsConfirmRelaychainInitiatedViewModelState: CovAConfirmStateOutputs {}
extension SelectValidatorsConfirmRelaychainExistingViewModelState: CovAConfirmStateOutputs {}
extension SelectValidatorsConfirmPoolInitiatedViewModelState: CovAConfirmStateOutputs {}
extension SelectValidatorsConfirmPoolExistingViewModelState: CovAConfirmStateOutputs {}

final class CovAConfirmListenerSpy: SelectValidatorsConfirmModelStateListener {
    private(set) var events: [String] = []

    func didReceiveError(error _: Error) {
        events.append("error")
    }

    func didStartNomination() {
        events.append("start")
    }

    func didCompleteNomination(txHash: String) {
        events.append("complete:\(txHash)")
    }

    func didFailNomination(error _: Error) {
        events.append("fail")
    }

    func feeParametersUpdated() {
        events.append("feeParameters")
    }

    func provideConfirmationState(viewModelState _: SelectValidatorsConfirmViewModelState) {
        events.append("confirmation")
    }

    func provideHints(viewModelState _: SelectValidatorsConfirmViewModelState) {
        events.append("hints")
    }

    func provideFee(viewModelState _: SelectValidatorsConfirmViewModelState) {
        events.append("fee")
    }

    func provideAsset(viewModelState _: SelectValidatorsConfirmViewModelState) {
        events.append("asset")
    }

    func count(_ event: String) -> Int {
        events.filter { $0 == event }.count
    }
}

enum CovAConfirmFixtures {
    static let chainAsset = CovAFixtures.chainAsset()
    static let wallet = CovAFixtures.wallet()
    static let targets = [CovAFixtures.validator(1), CovAFixtures.validator(2)]
    static let duration = StakingDuration(session: 3600, era: 6 * 3600, unlocking: 7 * 24 * 3600)

    static func payoutAccount() -> ChainAccountResponse {
        ChainAccountResponse(
            chainId: CovAFixtures.chainId,
            accountId: CovAFixtures.accountId(9),
            publicKey: CovAFixtures.accountId(9),
            name: "Payout",
            cryptoType: .sr25519,
            addressPrefix: 42,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: "cov-a-payout"
        )
    }

    static func controller() -> ChainAccountResponse {
        ChainAccountResponse(
            chainId: CovAFixtures.chainId,
            accountId: CovAFixtures.accountId(7),
            publicKey: CovAFixtures.accountId(7),
            name: "Controller",
            cryptoType: .sr25519,
            addressPrefix: 42,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: "cov-a-wallet"
        )
    }

    static func initiated(payout: Bool, amount: Decimal = 1) -> InitiatedBonding {
        InitiatedBonding(amount: amount, rewardDestination: payout ? .payout(account: payoutAccount()) : .restake)
    }

    static func existing(payout: Bool, nominated: Bool = true) -> ExistingBonding {
        ExistingBonding(
            stashAddress: CovAFixtures.address(7),
            controllerAccount: controller(),
            amount: 5,
            rewardDestination: payout ? .payout(account: CovAFixtures.address(9)) : .restake,
            selectedTargets: nominated ? targets : nil
        )
    }

    static func dataValidating() -> StakingDataValidatingFactory {
        StakingDataValidatingFactory(presentable: CovAConfirmWireframeStub())
    }

    static func callFactory() -> SubstrateCallFactoryProtocol {
        SubstrateCallFactoryDefault(runtimeService: CovARuntimeCodingServiceStub())
    }

    static func relaychainInitiated(payout: Bool = true, amount: Decimal = 1) -> SelectValidatorsConfirmRelaychainInitiatedViewModelState {
        SelectValidatorsConfirmRelaychainInitiatedViewModelState(
            targets: targets, maxTargets: 16, initiatedBonding: initiated(payout: payout, amount: amount), chainAsset: chainAsset,
            wallet: wallet, dataValidatingFactory: dataValidating(), callFactory: callFactory()
        )
    }

    static func relaychainExisting(payout: Bool = true) -> SelectValidatorsConfirmRelaychainExistingViewModelState {
        SelectValidatorsConfirmRelaychainExistingViewModelState(
            targets: targets, maxTargets: 16, existingBonding: existing(payout: payout), chainAsset: chainAsset, wallet: wallet,
            operationManager: OperationManager(), dataValidatingFactory: dataValidating(), callFactory: callFactory()
        )
    }

    static func poolInitiated(payout: Bool = false) -> SelectValidatorsConfirmPoolInitiatedViewModelState {
        SelectValidatorsConfirmPoolInitiatedViewModelState(
            poolId: 3, targets: targets, maxTargets: 16, initiatedBonding: initiated(payout: payout), chainAsset: chainAsset,
            wallet: wallet, dataValidatingFactory: dataValidating(), callFactory: callFactory()
        )
    }

    static func poolExisting(payout: Bool = false) -> SelectValidatorsConfirmPoolExistingViewModelState {
        SelectValidatorsConfirmPoolExistingViewModelState(
            poolId: 4, targets: targets, maxTargets: 16, existingBonding: existing(payout: payout, nominated: false),
            chainAsset: chainAsset, wallet: wallet, operationManager: OperationManager(),
            dataValidatingFactory: dataValidating(), callFactory: callFactory()
        )
    }

    static func balanceFactory() -> BalanceViewModelFactory {
        CovAFixtures.balanceFactory(chainAsset: chainAsset, wallet: wallet)
    }

    static func factories() -> [SelectValidatorsConfirmViewModelFactoryProtocol] {
        let balance = balanceFactory()
        let icons = UniversalIconGenerator()
        return [
            SelectValidatorsConfirmRelaychainInitiatedViewModelFactory(
                balanceViewModelFactory: balance, iconGenerator: icons, chainAsset: chainAsset
            ),
            SelectValidatorsConfirmRelaychainExistingViewModelFactory(
                balanceViewModelFactory: balance, iconGenerator: icons, chainAsset: chainAsset
            ),
            SelectValidatorsConfirmPoolInitiatedViewModelFactory(
                balanceViewModelFactory: balance, iconGenerator: icons, chainAsset: chainAsset
            ),
            SelectValidatorsConfirmPoolExistingViewModelFactory(
                balanceViewModelFactory: balance, iconGenerator: icons, chainAsset: chainAsset
            )
        ]
    }
}

final class CovASelectValidatorsConfirmStateTests: XCTestCase {
    private func allStates() -> [CovAConfirmStateOutputs] {
        [
            CovAConfirmFixtures.relaychainInitiated(),
            CovAConfirmFixtures.relaychainExisting(),
            CovAConfirmFixtures.poolInitiated(),
            CovAConfirmFixtures.poolExisting()
        ]
    }

    private func waitForConfirmation(_ listener: CovAConfirmListenerSpy) {
        CovAViewInspector.spin(until: { listener.count("confirmation") > 0 || listener.count("error") > 0 })
    }

    func testEveryStateRecordsChainParametersAndReportsFailures() {
        let accountInfo = WestendStub.accountInfo.item
        for state in allStates() {
            let listener = CovAConfirmListenerSpy()
            state.setStateListener(listener)

            state.didReceiveMinBond(result: .success(BigUInt(2_000_000_000_000)))
            state.didReceiveMaxNominatorsCount(result: .success(100))
            state.didReceiveCounterForNominators(result: .success(10))
            state.didReceiveStakingDuration(result: .success(CovAConfirmFixtures.duration))
            state.didReceive(paymentInfo: RuntimeDispatchInfo(feeValue: BigUInt(10_000_000_000)))
            state.didReceiveAccountInfo(result: .success(accountInfo))

            XCTAssertEqual(state.minNominatorBond, 2)
            XCTAssertEqual(state.maxNominatorsCount, 100)
            XCTAssertEqual(state.counterForNominators, 10)
            XCTAssertEqual(state.stakingDuration?.era, 6 * 3600)
            XCTAssertEqual(state.fee, Decimal(string: "0.01"))
            XCTAssertEqual(state.balance, 10)
            XCTAssertEqual(listener.events, ["hints", "fee"])

            state.didReceiveAccountInfo(result: .success(nil))
            XCTAssertEqual(state.balance, 0)
            state.didReceiveMinBond(result: .success(nil))
            XCTAssertNil(state.minNominatorBond)

            state.didReceiveMinBond(result: .failure(CovATestError.failed))
            state.didReceiveMaxNominatorsCount(result: .failure(CovATestError.failed))
            state.didReceiveCounterForNominators(result: .failure(CovATestError.failed))
            state.didReceiveStakingDuration(result: .failure(CovATestError.failed))
            state.didReceive(feeError: CovATestError.failed)
            state.didReceiveAccountInfo(result: .failure(CovATestError.failed))
            XCTAssertEqual(listener.count("error"), 6)

            state.didStartNomination()
            state.didCompleteNomination(txHash: "0xabc")
            state.didFailNomination(error: CovATestError.failed)
            XCTAssertEqual(Array(listener.events.suffix(3)), ["start", "complete:0xabc", "fail"])

            XCTAssertNotNil(state.createExtrinsicBuilderClosure())
            XCTAssertEqual(state.walletAccountAddress, CovAFixtures.address(7))
            XCTAssertFalse(state.validators(using: CovAFixtures.locale).isEmpty)
        }
    }

    func testInitiatedStatesBuildConfirmationModelsAtOnce() throws {
        let relay = CovAConfirmFixtures.relaychainInitiated(payout: true)
        let pool = CovAConfirmFixtures.poolInitiated(payout: false)
        let relayListener = CovAConfirmListenerSpy()
        let poolListener = CovAConfirmListenerSpy()
        relay.setStateListener(relayListener)
        pool.setStateListener(poolListener)

        relay.didSetup()
        pool.didSetup()

        let relayModel = try XCTUnwrap(relay.confirmationModel)
        XCTAssertEqual(relayModel.amount, 1)
        XCTAssertEqual(relayModel.wallet.username, "Cov wallet")
        XCTAssertEqual(relayModel.wallet.address, CovAFixtures.address(7))
        XCTAssertEqual(relayModel.targets.count, 2)
        XCTAssertEqual(relayModel.maxTargets, 16)
        XCTAssertFalse(relayModel.hasExistingBond)
        guard case let .payout(account) = relayModel.rewardDestination else { return XCTFail("payout expected") }
        XCTAssertEqual(account.address, CovAFixtures.address(9))
        XCTAssertEqual(account.username, "Payout")
        XCTAssertEqual(relay.payoutAccountAddress, CovAFixtures.address(9))
        XCTAssertEqual(relay.amount, 1)
        XCTAssertEqual(relay.validators(using: CovAFixtures.locale).count, 3)

        guard case .restake = try XCTUnwrap(pool.confirmationModel).rewardDestination else { return XCTFail("restake expected") }
        XCTAssertNil(pool.payoutAccountAddress)
        XCTAssertEqual(relayListener.events, ["confirmation"])
        XCTAssertEqual(poolListener.events, ["confirmation"])

        pool.didReceive(poolName: "Pool Three")
        pool.didReceive(error: CovATestError.failed)
        XCTAssertEqual(pool.poolName, "Pool Three")
        XCTAssertEqual(poolListener.events, ["confirmation", "confirmation", "error"])
    }

    func testExistingStatesBuildConfirmationModelsAsynchronously() throws {
        for payout in [true, false] {
            let relay = CovAConfirmFixtures.relaychainExisting(payout: payout)
            let pool = CovAConfirmFixtures.poolExisting(payout: payout)
            let relayListener = CovAConfirmListenerSpy()
            let poolListener = CovAConfirmListenerSpy()
            relay.setStateListener(relayListener)
            pool.setStateListener(poolListener)

            relay.didSetup()
            pool.didSetup()
            waitForConfirmation(relayListener)
            waitForConfirmation(poolListener)

            let relayModel = try XCTUnwrap(relay.confirmationModel)
            XCTAssertEqual(relayModel.wallet.username, "Controller")
            XCTAssertEqual(relayModel.amount, 5)
            XCTAssertTrue(relayModel.hasExistingBond)
            XCTAssertTrue(relayModel.hasExistingNomination)
            XCTAssertFalse(try XCTUnwrap(pool.confirmationModel).hasExistingNomination)
            XCTAssertEqual(relay.amount, 0)
            XCTAssertEqual(pool.amount, 0)
            if payout {
                guard case let .payout(account) = relayModel.rewardDestination else { return XCTFail("payout expected") }
                XCTAssertEqual(account.username, "Cov wallet")
                XCTAssertEqual(relay.payoutAccountAddress, CovAFixtures.address(9))
                XCTAssertEqual(pool.payoutAccountAddress, CovAFixtures.address(9))
            } else {
                guard case .restake = relayModel.rewardDestination else { return XCTFail("restake expected") }
                XCTAssertNil(relay.payoutAccountAddress)
                XCTAssertNil(pool.payoutAccountAddress)
            }
            XCTAssertEqual(pool.validators(using: CovAFixtures.locale).count, 2)
        }
        let pool = CovAConfirmFixtures.poolExisting()
        let listener = CovAConfirmListenerSpy()
        pool.setStateListener(listener)
        pool.didReceive(poolName: "Pool Four")
        pool.didReceive(error: CovATestError.failed)
        XCTAssertEqual(pool.poolName, "Pool Four")
        XCTAssertEqual(listener.events, ["confirmation", "error"])
    }

    // MARK: - View model factories

    private func preparedStates() -> [CovAConfirmStateOutputs] {
        let states = allStates()
        for state in states {
            let listener = CovAConfirmListenerSpy()
            state.setStateListener(listener)
            state.didSetup()
            waitForConfirmation(listener)
            state.didReceiveStakingDuration(result: .success(CovAConfirmFixtures.duration))
            state.didReceive(paymentInfo: RuntimeDispatchInfo(feeValue: BigUInt(10_000_000_000)))
        }
        (states[2] as? SelectValidatorsConfirmPoolInitiatedViewModelState)?.didReceive(poolName: "Pool Three")
        (states[3] as? SelectValidatorsConfirmPoolExistingViewModelState)?.didReceive(poolName: "Pool Four")
        return states
    }

    func testFactoriesBuildConfirmationFeeAndAssetViewModels() throws {
        let locale = CovAFixtures.locale
        let states = preparedStates()
        let factories = CovAConfirmFixtures.factories()
        for (index, (factory, state)) in zip(factories, states).enumerated() {
            let viewModel = try XCTUnwrap(try factory.buildViewModel(viewModelState: state)).value(for: locale)
            XCTAssertEqual(viewModel.validatorsCount, 2)
            XCTAssertEqual(viewModel.maxValidatorCount, 16)
            XCTAssertNotNil(viewModel.stakeAmountViewModel?.value(for: locale).amountTitle.string)
            switch index {
            case 0:
                XCTAssertEqual(viewModel.senderName, "Cov wallet")
                XCTAssertTrue(try XCTUnwrap(viewModel.amount).amount.contains("1"))
                guard case let .payout(_, title, address) = viewModel.rewardDestination else { return XCTFail("payout") }
                XCTAssertEqual(title, "Payout")
                XCTAssertEqual(address, CovAFixtures.address(9))
                XCTAssertNil(viewModel.poolName)
            case 1:
                XCTAssertEqual(viewModel.senderName, "Controller")
                XCTAssertNotNil(viewModel.rewardDestination)
                XCTAssertNil(viewModel.poolName)
            case 2:
                XCTAssertNil(viewModel.amount)
                XCTAssertNil(viewModel.rewardDestination)
                XCTAssertEqual(viewModel.poolName, "Pool Three")
            default:
                XCTAssertNil(viewModel.rewardDestination)
                XCTAssertEqual(viewModel.poolName, "Pool Four")
            }

            let fee = try XCTUnwrap(factory.buildFeeViewModel(viewModelState: state, priceData: nil)).value(for: locale)
            XCTAssertTrue(fee.amount.contains("0.01"), fee.amount)

            let asset = try XCTUnwrap(factory.buildAssetBalanceViewModel(viewModelState: state, priceData: nil, balance: 3))
                .value(for: locale)
            XCTAssertEqual(asset.symbol.uppercased(), "COV")
        }
    }

    func testFactoriesBuildHints() throws {
        let locale = CovAFixtures.locale
        let states = preparedStates()
        let factories = CovAConfirmFixtures.factories()
        for index in 0 ..< 3 {
            let hints = try XCTUnwrap(factories[index].buildHintsViewModel(viewModelState: states[index])).value(for: locale)
            XCTAssertEqual(hints.count, 4)
            XCTAssertTrue(hints[0].title.contains("6"), hints[0].title)
            XCTAssertTrue(hints[1].title.contains("7"), hints[1].title)
            XCTAssertNotNil(hints[2].icon)
        }
    }

    func testFactoriesRejectStatesOfOtherFlows() throws {
        let states = allStates()
        let factories = CovAConfirmFixtures.factories()
        for (index, factory) in factories.enumerated() {
            let foreign = states[(index + 1) % states.count]
            XCTAssertNil(try factory.buildViewModel(viewModelState: foreign))
            XCTAssertNil(factory.buildFeeViewModel(viewModelState: foreign, priceData: nil))
            XCTAssertNil(factory.buildAssetBalanceViewModel(viewModelState: foreign, priceData: nil, balance: nil))
            // the own state without a confirmation model, fee or duration builds nothing yet
            XCTAssertNil(try factory.buildViewModel(viewModelState: states[index]))
            XCTAssertNil(factory.buildFeeViewModel(viewModelState: states[index], priceData: nil))
            XCTAssertNil(factory.buildHintsViewModel(viewModelState: states[index]))
        }
    }
}
