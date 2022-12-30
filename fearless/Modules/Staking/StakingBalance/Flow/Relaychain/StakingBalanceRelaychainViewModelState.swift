import Foundation
import SoraFoundation

final class StakingBalanceRelaychainViewModelState {
    var stateListener: StakingBalanceModelStateListener?

    var controllerAccount: ChainAccountResponse?
    var stashAccount: ChainAccountResponse?
    var stakingLedger: StakingLedger?
    private var stashItem: StashItem?
    private var activeEra: EraIndex?
    private var eraCountdown: EraCountdown?
    private let countdownTimer: CountdownTimerProtocol
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    init(countdownTimer: CountdownTimerProtocol, dataValidatingFactory: StakingDataValidatingFactoryProtocol) {
        self.countdownTimer = countdownTimer
        self.dataValidatingFactory = dataValidatingFactory

        self.countdownTimer.delegate = self
    }

    var stakingBalanceData: StakingBalanceData? {
        guard let stakingLedger = stakingLedger,
              let activeEra = activeEra,
              let eraCountdown = eraCountdown else {
            return nil
        }

        return StakingBalanceData(
            stakingLedger: stakingLedger,
            activeEra: activeEra,
            eraCountdown: eraCountdown
        )
    }

    func stakeMoreValidators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.has(
                stash: stashAccount,
                for: stashItem?.stash ?? "",
                locale: locale
            )
        ]
    }

    func stakeLessValidators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.has(
                controller: controllerAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.unbondingsLimitNotReached(
                stakingLedger?.unlocking.count,
                locale: locale
            )
        ]
    }

    func revokeValidators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.has(
                controller: controllerAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            )
        ]
    }

    func unbondingMoreValidators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.has(
                controller: controllerAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            )
        ]
    }

    var bondMoreFlow: StakingBondMoreFlow? {
        .relaychain
    }

    var unbondFlow: StakingUnbondSetupFlow? {
        .relaychain
    }

    var revokeFlow: StakingRedeemConfirmationFlow? {
        .relaychain
    }

    var rebondCases: [StakingRebondOption] {
        StakingRebondOption.allCases
    }

    func decideRebondFlow(option: StakingRebondOption) {
        switch option {
        case .all:
            stateListener?.decideShowConfirmRebondFlow(flow: .relaychain(variant: .all))
        case .last:
            stateListener?.decideShowConfirmRebondFlow(flow: .relaychain(variant: .last))
        case .customAmount:
            stateListener?.decideShowSetupRebondFlow()
        }
    }

    deinit {
        countdownTimer.stop()
    }
}

extension StakingBalanceRelaychainViewModelState: StakingBalanceViewModelState {
    func setStateListener(_ stateListener: StakingBalanceModelStateListener?) {
        self.stateListener = stateListener
    }
}

extension StakingBalanceRelaychainViewModelState: StakingBalanceRelaychainStrategyOutput {
    func didReceive(ledgerResult: Result<StakingLedger?, Error>) {
        switch ledgerResult {
        case let .success(ledger):
            stakingLedger = ledger
            stateListener?.modelStateDidChanged(viewModelState: self)
        case .failure:
            stakingLedger = nil
            stateListener?.modelStateDidChanged(viewModelState: self)
        }
    }

    func didReceive(activeEraResult: Result<EraIndex?, Error>) {
        switch activeEraResult {
        case let .success(activeEra):
            self.activeEra = activeEra
            stateListener?.modelStateDidChanged(viewModelState: self)
        case .failure:
            activeEra = nil
            stateListener?.modelStateDidChanged(viewModelState: self)
        }
    }

    func didReceive(stashItemResult: Result<StashItem?, Error>) {
        switch stashItemResult {
        case let .success(stashItem):
            self.stashItem = stashItem
            if stashItem == nil {
                stateListener?.finishFlow()
            }
        case .failure:
            stashItem = nil
        }
    }

    func didReceive(controllerResult: Result<ChainAccountResponse?, Error>) {
        switch controllerResult {
        case let .success(controller):
            controllerAccount = controller
        case .failure:
            controllerAccount = nil
        }
    }

    func didReceive(stashResult: Result<ChainAccountResponse?, Error>) {
        switch stashResult {
        case let .success(stash):
            stashAccount = stash
        case .failure:
            stashAccount = nil
        }
    }

    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) {
        switch eraCountdownResult {
        case let .success(eraCountdown):
            self.eraCountdown = eraCountdown
            countdownTimer.start(with: eraCountdown.timeIntervalTillNextActiveEraStart(), runLoop: .main, mode: .common)
        case .failure:
            eraCountdown = nil
        }
    }
}

extension StakingBalanceRelaychainViewModelState: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didCountdown(remainedInterval _: TimeInterval) {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didStop(with _: TimeInterval) {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
