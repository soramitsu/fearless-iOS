import Foundation

extension BondedState {
    var status: NominationViewStatus {
        guard let eraStakers = commonData.eraStakersInfo else {
            return .undefined
        }

        return .inactive(era: eraStakers.era)
    }

    func createStatusPresentableViewModel(locale: Locale?) -> AlertPresentableViewModel? {
        switch status {
        case .inactive:
            return createInactiveStatus(locale: locale)
        case .active, .waiting, .undefined:
            return nil
        }
    }

    private func createInactiveStatus(locale: Locale?) -> AlertPresentableViewModel {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusAlertInactiveTitle(preferredLanguages: locale?.rLanguages)
        let message: String

        message = "You are neither nominating nor validating"

        return AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }
}
