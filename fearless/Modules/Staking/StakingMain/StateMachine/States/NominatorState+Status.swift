import Foundation
import IrohaCrypto
import BigInt

extension NominatorState {
    var status: NominationViewStatus {
        guard let eraStakers = commonData.eraStakersInfo else {
            return .undefined
        }

        do {
            let accountId = try SS58AddressFactory().accountId(from: stashItem.stash)

            let allNominators = eraStakers.validators.map(\.exposure.others)
                .flatMap { (nominators) -> [IndividualExposure] in
                    if let maxNominatorsPerValidator = commonData.maxNominatorsPerValidator {
                        return Array(nominators.prefix(Int(maxNominatorsPerValidator)))
                    } else {
                        return nominators
                    }
                }
                .reduce(into: Set<Data>()) { $0.insert($1.who) }

            if allNominators.contains(accountId) {
                return .active(era: eraStakers.era)
            }

            if nomination.submittedIn >= eraStakers.era {
                return .waiting(eraCountdown: commonData.eraCountdown)
            }

            return .inactive(era: eraStakers.era)

        } catch {
            return .undefined
        }
    }

    func createStatusPresentableViewModel(
        locale: Locale?
    ) -> AlertPresentableViewModel? {
        switch status {
        case .active:
            return createActiveStatus(locale: locale)
        case .inactive:
            return createInactiveStatus(locale: locale)
        case .waiting:
            return createWaitingStatus(locale: locale)
        case .undefined:
            return createUndefinedStatus(locale: locale)
        }
    }

    private func createActiveStatus(locale: Locale?) -> AlertPresentableViewModel? {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusAlertActiveTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingNominatorStatusAlertActiveMessage(preferredLanguages: locale?.rLanguages)

        return AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createInactiveStatus(
        locale: Locale?
    ) -> AlertPresentableViewModel? {
        guard let minStake = commonData.minStake else {
            return nil
        }

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusAlertInactiveTitle(preferredLanguages: locale?.rLanguages)
        let message: String

        if ledgerInfo.active < minStake {
            message = R.string.localizable
                .stakingNominatorStatusAlertLowStake(preferredLanguages: locale?.rLanguages)
        } else {
            message = R.string.localizable
                .stakingNominatorStatusAlertNoValidators(preferredLanguages: locale?.rLanguages)
        }

        return AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createWaitingStatus(locale: Locale?) -> AlertPresentableViewModel? {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusWaiting(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingNominatorStatusAlertWaitingMessage(preferredLanguages: locale?.rLanguages)

        return AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createUndefinedStatus(locale _: Locale?) -> AlertPresentableViewModel? {
        nil
    }
}
