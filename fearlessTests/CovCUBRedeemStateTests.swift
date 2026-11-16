import XCTest
import BigInt
import SSFModels
@testable import fearless

final class CovCUBRedeemListenerSpy: StakingRedeemModelStateListener, StakingRedeemConfirmationModelStateListener {
    private(set) var calls: [String] = []
    private(set) var submissions: [Result<String, Error>] = []

    func didReceiveError(error _: Error) { calls.append("error") }
    func didSubmitRedeeming(result: Result<String, Error>) {
        calls.append("submit")
        submissions.append(result)
    }

    func provideFeeViewModel() { calls.append("fee") }
    func provideAssetViewModel() { calls.append("asset") }
    func provideConfirmationViewModel() { calls.append("confirmation") }
    func refreshFeeIfNeeded() { calls.append("refresh") }

    func reset() { calls.removeAll() }
}

/// The redeem and redeem-confirmation relaychain states share one shape; this lets one test body drive both.
protocol CovCUBRedeemRelayDriving: AnyObject {
    var builderClosure: ExtrinsicBuilderClosure? { get }
    var reuseIdentifier: String? { get }
    var fee: Decimal? { get }
    var address: String? { get }
    var stakingLedger: StakingLedger? { get }
    var activeEra: UInt32? { get }
    var balance: Decimal? { get }
    var minimalBalance: BigUInt? { get }
    var controller: fearless.ChainAccountResponse? { get }
    var numberOfSlashingSpans: Int? { get }

    func validators(using locale: Locale) -> [DataValidating]
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveFee(result: Result<fearless.RuntimeDispatchInfo, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveController(result: Result<fearless.ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>)
    func didSubmitRedeeming(result: Result<String, Error>)
    func didReceiveSlashingSpans(result: Result<SlashingSpans?, Error>)
}

/// Same for the two pool states.
protocol CovCUBRedeemPoolDriving: AnyObject {
    var builderClosure: ExtrinsicBuilderClosure? { get }
    var reuseIdentifier: String? { get }
    var fee: Decimal? { get }
    var address: String? { get }
    var activeEra: UInt32? { get }
    var balance: Decimal? { get }
    var minimalBalance: BigUInt? { get }
    var numberOfSlashingSpans: Int? { get }
    var stakeInfo: StakingPoolMember? { get }

    func validators(using locale: Locale) -> [DataValidating]
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveFee(result: Result<fearless.RuntimeDispatchInfo, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didSubmitRedeeming(result: Result<String, Error>)
    func didReceiveSlashingSpans(result: Result<SlashingSpans?, Error>)
    func didReceiveStakeInfo(result: Result<StakingPoolMember?, Error>)
    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>)
}

extension StakingRedeemRelaychainViewModelState: CovCUBRedeemRelayDriving {}
extension StakingRedeemConfirmationRelaychainViewModelState: CovCUBRedeemRelayDriving {}
extension StakingRedeemPoolViewModelState: CovCUBRedeemPoolDriving {}
extension StakingRedeemConfirmationPoolViewModelState: CovCUBRedeemPoolDriving {}

final class CovCUBRedeemStateTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var errors: CovCUBStakingErrorSpy!
    private var validatingFactory: StakingDataValidatingFactory!
    private var listener: CovCUBRedeemListenerSpy!
    private let validationView = CovCUBValidationView()

    override func setUp() {
        super.setUp()
        chainAsset = CovCUBFixture.chainAsset()
        wallet = CovCUBFixture.wallet()
        errors = CovCUBStakingErrorSpy()
        validatingFactory = StakingDataValidatingFactory(presentable: errors)
        listener = CovCUBRedeemListenerSpy()
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        errors = nil
        validatingFactory = nil
        listener = nil
        super.tearDown()
    }

    private func relayStates() -> [CovCUBRedeemRelayDriving] {
        let redeem = StakingRedeemRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
        redeem.setStateListener(listener)
        let confirmation = StakingRedeemConfirmationRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
        confirmation.setStateListener(listener)
        return [redeem, confirmation]
    }

    private func poolStates() -> [CovCUBRedeemPoolDriving] {
        let redeem = StakingRedeemPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
        redeem.setStateListener(listener)
        let confirmation = StakingRedeemConfirmationPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
        confirmation.setStateListener(listener)
        return [redeem, confirmation]
    }

    // MARK: - Relaychain

    func testRelaychainWithdrawNeedsSlashingSpans() throws {
        for state in relayStates() {
            listener.reset()
            XCTAssertNil(state.builderClosure)
            XCTAssertEqual(state.reuseIdentifier, "0")

            state.didReceiveSlashingSpans(result: .success(try CovCUBFixture.slashingSpans(priorCount: 2)))
            XCTAssertEqual(state.numberOfSlashingSpans, 3)
            XCTAssertEqual(state.reuseIdentifier, "3")
            XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["withdraw_unbonded"])

            state.didReceiveSlashingSpans(result: .success(nil))
            XCTAssertEqual(state.numberOfSlashingSpans, 1)
            XCTAssertEqual(listener.calls, ["refresh", "refresh"])
        }
    }

    func testRelaychainOutputsUpdateStateAndListener() throws {
        for state in relayStates() {
            listener.reset()
            let account = try CovCUBFixture.account(for: chainAsset, wallet: wallet)

            XCTAssertNil(state.address)
            state.didReceiveStashItem(result: .success(CovCUBFixture.stashItem(controller: "redeem-ctrl")))
            XCTAssertEqual(state.address, "redeem-ctrl")
            state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 4)))
            XCTAssertEqual(state.balance, 4)
            state.didReceiveAccountInfo(result: .success(nil))
            XCTAssertNil(state.balance)
            state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 1, unlocking: [(2, 3)])))
            XCTAssertNotNil(state.stakingLedger)
            state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.4)))
            XCTAssertEqual(state.fee, 0.4)
            state.didReceiveExistentialDeposit(result: .success(CovCUBFixture.planks(1)))
            XCTAssertEqual(state.minimalBalance, CovCUBFixture.planks(1))
            state.didReceiveController(result: .success(account))
            state.didReceiveController(result: .success(nil))
            XCTAssertEqual(state.controller, account)
            state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(5)))
            XCTAssertEqual(state.activeEra, 5)
            state.didSubmitRedeeming(result: .success("0xredeem"))

            XCTAssertEqual(listener.calls, [
                "confirmation", "asset", "refresh",
                "fee",
                "asset", "refresh",
                "confirmation", "refresh",
                "confirmation", "refresh",
                "asset", "confirmation",
                "submit"
            ])
            XCTAssertEqual(try listener.submissions.last?.get(), "0xredeem")
        }
    }

    func testRelaychainFailuresAreReported() throws {
        for state in relayStates() {
            listener.reset()
            state.didReceiveAccountInfo(result: .failure(CovCUBTestError.failed))
            state.didReceiveStakingLedger(result: .failure(CovCUBTestError.failed))
            state.didReceiveFee(result: .failure(CovCUBTestError.failed))
            state.didReceiveExistentialDeposit(result: .failure(CovCUBTestError.failed))
            state.didReceiveController(result: .failure(CovCUBTestError.failed))
            state.didReceiveStashItem(result: .failure(CovCUBTestError.failed))
            state.didReceiveActiveEra(result: .failure(CovCUBTestError.failed))
            state.didReceiveSlashingSpans(result: .failure(CovCUBTestError.failed))
            XCTAssertEqual(listener.calls, Array(repeating: "error", count: 8))
        }
    }

    func testRelaychainValidators() throws {
        validatingFactory.view = validationView
        for state in relayStates() {
            listener.reset()
            XCTAssertEqual(
                CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english)),
                [.error, .error, .error, .error]
            )
            XCTAssertEqual(listener.calls, ["refresh"])

            state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 1, unlocking: [(2, 3)])))
            state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(4)))
            state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
            state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 1)))
            state.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))
            XCTAssertEqual(
                CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english)),
                [nil, nil, nil, nil]
            )
        }
        XCTAssertEqual(errors.presented, [
            "noRedeemables", "feeNotReceived", "feeTooHigh", "missingController",
            "noRedeemables", "feeNotReceived", "feeTooHigh", "missingController"
        ])
    }

    // MARK: - Pool

    func testPoolWithdrawNeedsSlashingSpans() throws {
        let address = try CovCUBFixture.address(for: chainAsset, wallet: wallet)
        for state in poolStates() {
            listener.reset()
            XCTAssertNil(state.builderClosure)
            XCTAssertEqual(state.reuseIdentifier, "0")
            XCTAssertEqual(state.address, address)

            state.didReceiveSlashingSpans(result: .success(try CovCUBFixture.slashingSpans(priorCount: 0)))
            XCTAssertEqual(state.numberOfSlashingSpans, 1)
            XCTAssertEqual(state.reuseIdentifier, "1")
            XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["pool_withdraw_unbonded"])
            XCTAssertEqual(listener.calls, ["refresh"])
        }
    }

    func testPoolOutputsUpdateStateAndListener() throws {
        for state in poolStates() {
            listener.reset()
            state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 6, frozen: 1)))
            XCTAssertEqual(state.balance, 5)
            state.didReceiveAccountInfo(result: .success(nil))
            XCTAssertNil(state.balance)
            state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.05)))
            XCTAssertEqual(state.fee, 0.05)
            state.didReceiveExistentialDeposit(result: .success(CovCUBFixture.planks(2)))
            XCTAssertEqual(state.minimalBalance, CovCUBFixture.planks(2))
            state.didReceiveStakeInfo(result: .success(try CovCUBFixture.poolMember(points: 1, unbonding: [(1, 2)])))
            XCTAssertEqual(state.stakeInfo?.unbondingEras.count, 1)
            state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(3)))
            XCTAssertEqual(state.activeEra, 3)
            state.didSubmitRedeeming(result: .failure(CovCUBTestError.failed))

            XCTAssertEqual(listener.calls, [
                "asset", "asset",
                "fee",
                "asset", "refresh",
                "asset", "confirmation",
                "asset", "confirmation",
                "submit"
            ])

            listener.reset()
            state.didReceiveAccountInfo(result: .failure(CovCUBTestError.failed))
            state.didReceiveFee(result: .failure(CovCUBTestError.failed))
            state.didReceiveExistentialDeposit(result: .failure(CovCUBTestError.failed))
            state.didReceiveSlashingSpans(result: .failure(CovCUBTestError.failed))
            state.didReceiveStakeInfo(result: .failure(CovCUBTestError.failed))
            state.didReceiveActiveEra(result: .failure(CovCUBTestError.failed))
            XCTAssertEqual(listener.calls, Array(repeating: "error", count: 6))
        }
    }

    func testPoolValidators() throws {
        validatingFactory.view = validationView
        for state in poolStates() {
            listener.reset()
            XCTAssertEqual(
                CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english)),
                [.error, .error]
            )
            XCTAssertEqual(listener.calls, ["refresh"])

            state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
            state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 0.05)))
            XCTAssertEqual(
                CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english)),
                [nil, .error]
            )

            state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 1)))
            XCTAssertEqual(
                CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english)),
                [nil, nil]
            )
        }
        XCTAssertEqual(errors.presented, [
            "feeNotReceived", "feeTooHigh", "feeTooHigh",
            "feeNotReceived", "feeTooHigh", "feeTooHigh"
        ])
    }
}
