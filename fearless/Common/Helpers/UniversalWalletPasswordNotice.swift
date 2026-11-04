import Foundation
import UIKit

/// The one short notice about universal accounts a wallet's password does not protect yet:
/// the old addresses, the new password-protected ones to move funds to, and Switch.
enum UniversalWalletPasswordNotice {
    static func notice(
        for accounts: [UniversalWalletNoPasswordAccount],
        locale: Locale,
        onSwitch: @escaping () -> Void,
        onCopy: @escaping (UniversalWalletNoPasswordAccount) -> Void,
        onDismiss: @escaping () -> Void
    ) -> SheetAlertPresentableViewModel {
        let languages = locale.rLanguages
        let rows = accounts.map {
            R.string.localizable.universalPasswordNoticeRow(
                $0.networkName,
                $0.oldAddress,
                $0.newAddress,
                preferredLanguages: languages
            )
        }
        let message = ([R.string.localizable.universalPasswordNoticeMessage(preferredLanguages: languages)] + rows)
            .joined(separator: "\n\n")

        let switchAction = SheetAlertPresentableAction(
            title: R.string.localizable.universalPasswordNoticeSwitch(preferredLanguages: languages),
            style: .pinkBackgroundWhiteText,
            handler: onSwitch
        )
        let copyActions = accounts.map { account in
            SheetAlertPresentableAction(
                title: R.string.localizable.universalPasswordNoticeCopy(
                    account.networkName,
                    preferredLanguages: languages
                ),
                style: .grayBackgroundWhiteText,
                handler: { onCopy(account) }
            )
        }

        return SheetAlertPresentableViewModel(
            title: R.string.localizable.universalPasswordNoticeTitle(preferredLanguages: languages),
            message: message,
            actions: [switchAction] + copyActions,
            closeAction: R.string.localizable.universalPasswordNoticeLater(preferredLanguages: languages),
            dismissCompletion: onDismiss,
            icon: R.image.iconWarningBig(),
            scrollableContent: true
        )
    }

    static func arrivals(
        _ arrivals: [UniversalWalletOldAddressArrival],
        locale: Locale,
        onDismiss: @escaping () -> Void
    ) -> SheetAlertPresentableViewModel {
        let languages = locale.rLanguages
        let row = { (arrival: UniversalWalletOldAddressArrival) -> String in
            guard let balance = arrival.balance else {
                return R.string.localizable.universalPasswordArrivalRow(
                    arrival.networkName, arrival.oldAddress, preferredLanguages: languages
                )
            }
            return R.string.localizable.universalPasswordArrivalRowBalance(
                arrival.networkName, arrival.oldAddress, balance, preferredLanguages: languages
            )
        }
        let atOld = arrivals.filter { !$0.atProtectedAddress }
        let atProtected = arrivals.filter(\.atProtectedAddress)
        var sections: [String] = []
        if !atOld.isEmpty {
            sections += [R.string.localizable.universalPasswordArrivalMessage(preferredLanguages: languages)]
                + atOld.map(row)
        }
        if !atProtected.isEmpty {
            sections += [R.string.localizable.universalPasswordArrivalProtectedMessage(preferredLanguages: languages)]
                + atProtected.map(row)
        }
        let title = atProtected.isEmpty
            ? R.string.localizable.universalPasswordArrivalTitle(preferredLanguages: languages)
            : R.string.localizable.universalPasswordArrivalProtectedTitle(preferredLanguages: languages)

        return SheetAlertPresentableViewModel(
            title: title,
            message: sections.joined(separator: "\n\n"),
            actions: [],
            closeAction: R.string.localizable.commonOk(preferredLanguages: languages),
            dismissCompletion: onDismiss,
            icon: R.image.iconWarningBig(),
            scrollableContent: true
        )
    }

    static func outcomes(
        _ outcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome],
        for accounts: [UniversalWalletNoPasswordAccount],
        locale: Locale,
        onDismiss: (() -> Void)? = nil
    ) -> SheetAlertPresentableViewModel {
        let languages = locale.rLanguages
        let lines = accounts.map { account -> String in
            switch outcomes[account.slot] ?? .unchecked {
            case .switched:
                return R.string.localizable.universalPasswordSwitchSwitched(
                    account.networkName,
                    preferredLanguages: languages
                )
            case .stillFunded:
                return R.string.localizable.universalPasswordSwitchFunded(
                    account.networkName,
                    preferredLanguages: languages
                )
            case .unchecked:
                return R.string.localizable.universalPasswordSwitchUnchecked(
                    account.networkName,
                    preferredLanguages: languages
                )
            }
        }
        let allSwitched = accounts.allSatisfy { outcomes[$0.slot] == .switched }

        return SheetAlertPresentableViewModel(
            title: R.string.localizable.universalPasswordNoticeTitle(preferredLanguages: languages),
            message: lines.joined(separator: "\n"),
            actions: [],
            closeAction: R.string.localizable.commonOk(preferredLanguages: languages),
            dismissCompletion: onDismiss,
            icon: allSwitched ? R.image.iconValidBig() : R.image.iconWarningBig()
        )
    }
}
