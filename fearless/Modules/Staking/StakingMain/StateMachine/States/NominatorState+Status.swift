import Foundation
import IrohaCrypto
import BigInt

extension NominatorState {
    var status: NominationViewStatus {
        guard
            let eraStakers = commonData.eraStakersInfo,
            let electionStatus = commonData.electionStatus else {
            return .undefined
        }

        if case .open = electionStatus {
            return .election
        }

        do {
            let accountId = try SS58AddressFactory().accountId(from: stashItem.stash)

            if eraStakers.validators
                .first(where: { $0.exposure.others.contains(where: { $0.who == accountId})}) != nil {
                return .active(era: eraStakers.era)
            }

            if nomination.submittedIn >= eraStakers.era {
                return .waiting
            }

            return .inactive(era: eraStakers.era)

        } catch {
            return .undefined
        }
    }

    func createStatusPresentableViewModel(for minimumStake: BigUInt?,
                                          locale: Locale?) -> AlertPresentableViewModel? {
        switch status {
        case .active:
            return createActiveStatus(for: minimumStake, locale: locale)
        case .inactive:
            return createInactiveStatus(for: minimumStake, locale: locale)
        case .waiting:
            return createWaitingStatus(for: minimumStake, locale: locale)
        case .election:
            return createElectionStatus(for: minimumStake, locale: locale)
        case .undefined:
            return createUndefinedStatus(for: minimumStake, locale: locale)
        }
    }

    private func createActiveStatus(for minimumStake: BigUInt?,
                                    locale: Locale?) -> AlertPresentableViewModel? {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusAlertActiveTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingNominatorStatusAlertActiveMessage(preferredLanguages: locale?.rLanguages)

        return AlertPresentableViewModel(title: title,
                                         message: message,
                                         actions: [],
                                         closeAction: closeAction)
    }

    private func createInactiveStatus(for minimumStake: BigUInt?,
                                      locale: Locale?) -> AlertPresentableViewModel? {
        guard let minimumStake = minimumStake else {
            return nil
        }

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusAlertInactiveTitle(preferredLanguages: locale?.rLanguages)
        let message: String

        if ledgerInfo.active < minimumStake {
            message = R.string.localizable
                .stakingNominatorStatusAlertLowStake(preferredLanguages: locale?.rLanguages)
        } else {
            message = R.string.localizable
                .stakingNominatorStatusAlertNoValidators(preferredLanguages: locale?.rLanguages)
        }

        return AlertPresentableViewModel(title: title,
                                         message: message,
                                         actions: [],
                                         closeAction: closeAction)
    }

    private func createWaitingStatus(for minimumStake: BigUInt?,
                                     locale: Locale?) -> AlertPresentableViewModel? {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusWaiting(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingNominatorStatusAlertWaitingMessage(preferredLanguages: locale?.rLanguages)

        return AlertPresentableViewModel(title: title,
                                         message: message,
                                         actions: [],
                                         closeAction: closeAction)
    }

    private func createElectionStatus(for minimumStake: BigUInt?,
                                      locale: Locale?) -> AlertPresentableViewModel? {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusElection(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingNominatorStatusAlertElectionMessage(preferredLanguages: locale?.rLanguages)

        return AlertPresentableViewModel(title: title,
                                         message: message,
                                         actions: [],
                                         closeAction: closeAction)
    }

    private func createUndefinedStatus(for minimumStake: BigUInt?,
                                       locale: Locale?) -> AlertPresentableViewModel? {
        return nil
    }
}
