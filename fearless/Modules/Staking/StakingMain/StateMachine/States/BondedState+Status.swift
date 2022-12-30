import Foundation

extension BondedState {
    var status: NominationViewStatus {
        guard let eraStakers = commonData.eraStakersInfo else {
            return .undefined
        }

        return .inactive(era: eraStakers.activeEra)
    }

    func createStatusPresentableViewModel(locale: Locale?) -> SheetAlertPresentableViewModel? {
        switch status {
        case .inactive:
            return createInactiveStatus(locale: locale)
        default:
            return nil
        }
    }

    private func createInactiveStatus(locale: Locale?) -> SheetAlertPresentableViewModel {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusAlertInactiveTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingBondedInactive(preferredLanguages: locale?.rLanguages)

        return SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }
}
