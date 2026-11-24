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

/// iOS and iPadOS releases that contain the flaws used by the 2026 wallet-stealing exploit
/// chains (Coruna, SilkPath, DarkSword and GhostWave, delivered by the MoldyRoost ad campaign).
/// On a vulnerable release a web page alone can take over the device; the payloads then read
/// the keychain, app files, Notes, Photos and screenshots.
///
/// Fixed releases per line, from Apple's security notes: 15.8.7 and 16.7.15 (Coruna backports),
/// 18.7.7 and 26.3 (DarkSword). 17 has no fixed release; some iPads stop at iPadOS 17, so the
/// notice asks for any update available for the device rather than a specific version.
enum OperatingSystemExploitAdvisory {
    /// The campaign only runs on iPhone, iPad and iPod touch. On a Mac or Apple Vision Pro the
    /// reported version is not an iOS release, so the table does not apply.
    static var runsOnIPhoneOrIPadHardware: Bool {
        let info = ProcessInfo.processInfo
        if info.isiOSAppOnMac || info.isMacCatalystApp {
            return false
        }
        if #available(iOS 26.1, *), info.isiOSAppOnVision {
            return false
        }
        return true
    }

    static func isExposed(
        _ version: OperatingSystemVersion,
        runsOnIPhoneOrIPad: Bool = runsOnIPhoneOrIPadHardware
    ) -> Bool {
        guard runsOnIPhoneOrIPad else {
            return false
        }

        let fixed: (minor: Int, patch: Int)
        switch version.majorVersion {
        case ..<15:
            return true
        case 15:
            fixed = (8, 7)
        case 16:
            fixed = (7, 15)
        case 17:
            return true
        case 18:
            fixed = (7, 7)
        case 26:
            fixed = (3, 0)
        default:
            // 19-25 were never released; 27 and later are newer than every known chain.
            return false
        }

        return (version.minorVersion, version.patchVersion) < fixed
    }

    static func versionString(_ version: OperatingSystemVersion) -> String {
        "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}

/// Asks people on an exposed iOS release to update it. Shown once per iOS release: closing it
/// keeps it away until the phone runs another release that is still exposed.
protocol OperatingSystemSecurityNoticeTracking: AnyObject {
    var isPending: Bool { get }
    func acknowledge()
}

final class OperatingSystemSecurityNoticeTracker: OperatingSystemSecurityNoticeTracking {
    private let settings: SettingsManagerProtocol
    private let version: () -> OperatingSystemVersion
    private let isExposed: (OperatingSystemVersion) -> Bool

    init(
        settings: SettingsManagerProtocol,
        version: @escaping () -> OperatingSystemVersion = { ProcessInfo.processInfo.operatingSystemVersion },
        isExposed: @escaping (OperatingSystemVersion) -> Bool = { OperatingSystemExploitAdvisory.isExposed($0) }
    ) {
        self.settings = settings
        self.version = version
        self.isExposed = isExposed
    }

    var isPending: Bool {
        let current = version()
        guard isExposed(current) else {
            return false
        }
        return acknowledgedVersion != OperatingSystemExploitAdvisory.versionString(current)
    }

    func acknowledge() {
        settings.set(
            value: OperatingSystemExploitAdvisory.versionString(version()),
            for: SettingsKey.operatingSystemSecurityNotice.rawValue
        )
    }

    private var acknowledgedVersion: String? {
        settings.string(for: SettingsKey.operatingSystemSecurityNotice.rawValue)
    }
}

extension SheetAlertPresentableViewModel {
    /// One OK button and no corner close button, like the update notice.
    static func operatingSystemSecurityNotice(
        locale: Locale,
        onClose: @escaping () -> Void
    ) -> SheetAlertPresentableViewModel {
        let languages = locale.rLanguages

        return SheetAlertPresentableViewModel(
            title: R.string.localizable.osSecurityNoticeTitle(preferredLanguages: languages),
            message: R.string.localizable.osSecurityNoticeMessage(preferredLanguages: languages),
            actions: [],
            closeAction: R.string.localizable.commonOk(preferredLanguages: languages),
            dismissCompletion: onClose,
            icon: R.image.iconWarningBig(),
            showsCloseButton: false
        )
    }
}
