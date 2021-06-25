import Foundation
import IrohaCrypto
import BigInt

extension ValidatorState {
    var status: ValidationViewStatus {
        guard let eraStakers = commonData.eraStakersInfo else {
            return .undefined
        }

        do {
            let accountId = try SS58AddressFactory().accountId(from: stashItem.stash)

            if eraStakers.validators
                .first(where: { $0.accountId == accountId }) != nil {
                return .active(era: eraStakers.era)
            }
            return .inactive(era: eraStakers.era)

        } catch {
            return .undefined
        }
    }

    func createStatusPresentableViewModel(
        for locale: Locale?
    ) -> AlertPresentableViewModel? {
        switch status {
        case .active:
            return createActiveStatus(for: locale)
        case .inactive:
            return createInactiveStatus(for: locale)
        case .undefined:
            return createUndefinedStatus(for: locale)
        }
    }

    private func createActiveStatus(
        for locale: Locale?
    ) -> AlertPresentableViewModel? {
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
        for locale: Locale?
    ) -> AlertPresentableViewModel? {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusAlertInactiveTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingNominatorStatusAlertNoValidators(preferredLanguages: locale?.rLanguages)

        return AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createUndefinedStatus(
        for _: Locale?
    ) -> AlertPresentableViewModel? {
        nil
    }
}
