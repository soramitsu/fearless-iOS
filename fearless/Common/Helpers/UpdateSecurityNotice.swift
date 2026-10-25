import Foundation
import SoraKeystore
import UIKit

/// Remembers whether people who updated the app still have to see the security notice:
/// their mobile wallets are safe, and only funds in wallets used with the old Chrome extension
/// need moving.
protocol UpdateSecurityNoticeTracking: AnyObject {
    /// True until the notice has been shown and closed.
    var isPending: Bool { get }

    /// Called at every startup once the stored wallets are known, before onboarding can add one.
    /// Only the first call decides: an install that already had wallets was updated and gets the
    /// notice; one without (a fresh install) never does.
    func recordStartup(hadStoredWallets: Bool)

    /// The user closed the notice, so it is not shown again.
    func acknowledge()
}

final class UpdateSecurityNoticeTracker: UpdateSecurityNoticeTracking {
    private enum State: String {
        case pending
        case done
    }

    private let settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol) {
        self.settings = settings
    }

    var isPending: Bool {
        state == .pending
    }

    func recordStartup(hadStoredWallets: Bool) {
        guard state == nil else {
            return
        }

        save(hadStoredWallets ? .pending : .done)
    }

    func acknowledge() {
        save(.done)
    }

    private var state: State? {
        settings.string(for: SettingsKey.updateSecurityNotice.rawValue).flatMap(State.init(rawValue:))
    }

    private func save(_ state: State) {
        settings.set(value: state.rawValue, for: SettingsKey.updateSecurityNotice.rawValue)
    }
}

extension SheetAlertPresentableViewModel {
    /// The notice sheet: one OK button and no corner close button, so the user closes it on purpose.
    static func updateSecurityNotice(locale: Locale, onClose: @escaping () -> Void) -> SheetAlertPresentableViewModel {
        let languages = locale.rLanguages

        return SheetAlertPresentableViewModel(
            title: R.string.localizable.updateSecurityNoticeTitle(preferredLanguages: languages),
            message: R.string.localizable.updateSecurityNoticeMessage(preferredLanguages: languages),
            actions: [],
            closeAction: R.string.localizable.commonOk(preferredLanguages: languages),
            dismissCompletion: onClose,
            icon: R.image.iconValidBig(),
            showsCloseButton: false
        )
    }
}
