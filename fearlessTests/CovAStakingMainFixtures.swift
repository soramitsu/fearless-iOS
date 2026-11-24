import BigInt
import Foundation
import SoraFoundation
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

/// Fixtures for the staking main state machine and its view models.
enum CovAStakingMainFixtures {
    static let stashSeed: UInt8 = 7
    static var stashAddress: AccountAddress {
        CovAFixtures.address(stashSeed)
    }

    static func stash(controller: UInt8 = 7) -> StashItem {
        StashItem(stash: stashAddress, controller: CovAFixtures.address(controller))
    }

    static func ledger(active: String = "1000000000000", unlocking: [(String, String)] = []) throws -> StakingLedger {
        let chunks = unlocking.map { ["value": $0.0, "era": $0.1] }
        let payload: [String: Any] = [
            "stash": CovAFixtures.accountId(stashSeed).toHex(includePrefix: true),
            "total": active,
            "active": active,
            "unlocking": chunks,
            "claimedRewards": []
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(StakingLedger.self, from: data)
    }

    static func nomination(submittedIn: UInt32 = 1, targets: [UInt8] = [1, 2]) throws -> Nomination {
        let payload: [String: Any] = [
            "targets": targets.map { CovAFixtures.accountId($0).toHex(includePrefix: true) },
            "submittedIn": "\(submittedIn)"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(Nomination.self, from: data)
    }

    static func prefs(commission: BigUInt = 50_000_000) -> ValidatorPrefs {
        ValidatorPrefs(commission: commission, blocked: false)
    }

    static func exposure(nominators: [UInt8], validator: UInt8) throws -> EraValidatorInfo {
        let others = try nominators.map { seed -> IndividualExposure in
            let json = try JSONSerialization.data(withJSONObject: [
                "who": CovAFixtures.accountId(seed).base64EncodedString(),
                "value": "200"
            ])
            return try JSONDecoder().decode(IndividualExposure.self, from: json)
        }
        return EraValidatorInfo(
            accountId: CovAFixtures.accountId(validator),
            exposure: ValidatorExposure(total: 1000, own: 100, others: others),
            prefs: prefs()
        )
    }

    static func eraStakers(activeEra: EraIndex = 10, nominators: [UInt8] = [7], validators: [UInt8] = [1]) throws -> EraStakersInfo {
        try EraStakersInfo(activeEra: activeEra, validators: validators.map { try exposure(nominators: nominators, validator: $0) })
    }

    static func eraCountdown(activeEra: EraIndex = 10) -> EraCountdown {
        EraCountdown(
            activeEra: activeEra,
            currentEra: activeEra,
            eraLength: 6,
            sessionLength: 600,
            activeEraStartSessionIndex: 60,
            currentSessionIndex: 62,
            currentSlot: 37300,
            genesisSlot: 0,
            blockCreationTime: 6000,
            createdAtDate: Date()
        )
    }

    static func totalReward() -> TotalRewardItem {
        TotalRewardItem(address: stashAddress, amount: AmountDecimal(value: 12))
    }
}

/// A reward calculator with fixed returns.
struct CovARewardCalculatorStub: RewardCalculatorEngineProtocol {
    var rewardAssetRate: Decimal = 1

    func calculateEarnings(amount: Decimal, validatorAccountId _: AccountId, isCompound _: Bool, period _: CalculationPeriod) throws -> Decimal {
        amount * 0.1
    }

    func calculateMaxEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal {
        amount * 0.2
    }

    func calculateAvgEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal {
        amount * 0.15
    }

    func calculatorReturn(isCompound _: Bool, period: CalculationPeriod, type _: RewardReturnType) -> Decimal {
        switch period {
        case .year:
            return 0.12
        default:
            return 0.01
        }
    }

    func maxEarningsTitle(locale _: Locale) -> String {
        "Max"
    }

    func avgEarningTitle(locale _: Locale) -> String {
        "Avg"
    }
}

/// Records state-machine transitions and the concrete state visited each time.
final class CovAStakingStateRecorder: StakingStateMachineDelegate, StakingStateVisitorProtocol {
    private(set) var visited: [String] = []

    func stateMachineDidChangeState(_ stateMachine: StakingStateMachineProtocol) {
        stateMachine.state.accept(visitor: self)
    }

    func visit(state _: InitialRelaychainStakingState) {
        visited.append("initial")
    }

    func visit(state _: NoStashState) {
        visited.append("noStash")
    }

    func visit(state _: StashState) {
        visited.append("stash")
    }

    func visit(state _: PendingBondedState) {
        visited.append("pendingBonded")
    }

    func visit(state _: BondedState) {
        visited.append("bonded")
    }

    func visit(state _: PendingNominatorState) {
        visited.append("pendingNominator")
    }

    func visit(state _: NominatorState) {
        visited.append("nominator")
    }

    func visit(state _: PendingValidatorState) {
        visited.append("pendingValidator")
    }

    func visit(state _: ValidatorState) {
        visited.append("validator")
    }

    var last: String? {
        visited.last
    }
}
