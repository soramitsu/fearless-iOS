import AppKit
import Observation
import SwiftUI
import WalletCore

/// Light, dark or follow the system.
public enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "Match System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// Preferences owned by the interface, kept in UserDefaults. Nothing secret
/// is ever stored here: no passwords, phrases or keys.
///
/// A setter does nothing when the value is unchanged: no observation
/// update and no write to UserDefaults.
@MainActor
@Observable
public final class AppSettings {
    /// Idle minutes offered for auto-lock; 0 means never.
    public static let autoLockChoices = [1, 5, 15, 30, 60, 0]

    private enum Key {
        static let fiat = "fearless.ui.fiatCurrency"
        static let appearance = "fearless.ui.appearance"
        static let hideZero = "fearless.ui.hideZeroBalances"
        static let showTestnets = "fearless.ui.showTestnets"
        static let menuBarExtra = "fearless.ui.menuBarExtra"
        static let balancesHidden = "fearless.ui.balancesHidden"
        static let autoLockMinutes = "fearless.ui.autoLockMinutes"
        static let lockOnSleep = "fearless.ui.lockOnSleep"
        static let lockOnScreenLock = "fearless.ui.lockOnScreenLock"
        static let hiddenAssets = "fearless.ui.hiddenAssets"
        static let selectedWallet = "fearless.ui.selectedWallet"
        static let inspectorVisible = "fearless.ui.inspectorVisible"
    }

    private struct Values {
        var fiatCode: String
        var appearance: AppearancePreference
        var hideZeroBalances: Bool
        var showTestnets: Bool
        var balancesHidden: Bool
        var autoLockMinutes: Int
        var lockOnSleep: Bool
        var lockOnScreenLock: Bool
        var hiddenAssetKeys: Set<String>
        var selectedWalletID: String?
        var inspectorVisible: Bool
    }

    @ObservationIgnored private let defaults: UserDefaults
    private var values: Values
    /// Kept apart from `values`: the scene list reads only this flag, so it
    /// is not re-evaluated when any other preference changes.
    private var menuBarExtraFlag: Bool

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.fiat: "usd",
            Key.appearance: AppearancePreference.system.rawValue,
            Key.hideZero: false,
            Key.showTestnets: false,
            Key.menuBarExtra: false,
            Key.balancesHidden: false,
            Key.autoLockMinutes: 5,
            Key.lockOnSleep: true,
            Key.lockOnScreenLock: true,
            Key.inspectorVisible: true
        ])
        menuBarExtraFlag = defaults.bool(forKey: Key.menuBarExtra)
        values = Values(
            fiatCode: defaults.string(forKey: Key.fiat) ?? "usd",
            appearance: AppearancePreference(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system,
            hideZeroBalances: defaults.bool(forKey: Key.hideZero),
            showTestnets: defaults.bool(forKey: Key.showTestnets),
            balancesHidden: defaults.bool(forKey: Key.balancesHidden),
            autoLockMinutes: defaults.integer(forKey: Key.autoLockMinutes),
            lockOnSleep: defaults.bool(forKey: Key.lockOnSleep),
            lockOnScreenLock: defaults.bool(forKey: Key.lockOnScreenLock),
            hiddenAssetKeys: Set(defaults.stringArray(forKey: Key.hiddenAssets) ?? []),
            selectedWalletID: defaults.string(forKey: Key.selectedWallet),
            inspectorVisible: defaults.bool(forKey: Key.inspectorVisible)
        )
    }

    // MARK: General

    public var fiatCode: String {
        get { values.fiatCode }
        set {
            guard values.fiatCode != newValue else { return }
            values.fiatCode = newValue
            defaults.set(newValue, forKey: Key.fiat)
        }
    }

    /// The selected display currency (US dollar if the stored code is unknown).
    public var fiat: FiatCurrency {
        FiatCurrency.named(values.fiatCode) ?? .usd
    }

    public var appearance: AppearancePreference {
        get { values.appearance }
        set {
            guard values.appearance != newValue else { return }
            values.appearance = newValue
            defaults.set(newValue.rawValue, forKey: Key.appearance)
        }
    }

    public var hideZeroBalances: Bool {
        get { values.hideZeroBalances }
        set {
            guard values.hideZeroBalances != newValue else { return }
            values.hideZeroBalances = newValue
            defaults.set(newValue, forKey: Key.hideZero)
        }
    }

    public var showTestnets: Bool {
        get { values.showTestnets }
        set {
            guard values.showTestnets != newValue else { return }
            values.showTestnets = newValue
            defaults.set(newValue, forKey: Key.showTestnets)
        }
    }

    public var menuBarExtraEnabled: Bool {
        get { menuBarExtraFlag }
        set {
            guard menuBarExtraFlag != newValue else { return }
            menuBarExtraFlag = newValue
            defaults.set(newValue, forKey: Key.menuBarExtra)
        }
    }

    /// Privacy mode: amounts are masked everywhere.
    public var balancesHidden: Bool {
        get { values.balancesHidden }
        set {
            guard values.balancesHidden != newValue else { return }
            values.balancesHidden = newValue
            defaults.set(newValue, forKey: Key.balancesHidden)
        }
    }

    public var inspectorVisible: Bool {
        get { values.inspectorVisible }
        set {
            guard values.inspectorVisible != newValue else { return }
            values.inspectorVisible = newValue
            defaults.set(newValue, forKey: Key.inspectorVisible)
        }
    }

    // MARK: Security

    /// Idle minutes before the app locks; 0 means never.
    public var autoLockMinutes: Int {
        get { values.autoLockMinutes }
        set {
            guard values.autoLockMinutes != max(0, newValue) else { return }
            values.autoLockMinutes = max(0, newValue)
            defaults.set(max(0, newValue), forKey: Key.autoLockMinutes)
        }
    }

    public var lockOnSleep: Bool {
        get { values.lockOnSleep }
        set {
            guard values.lockOnSleep != newValue else { return }
            values.lockOnSleep = newValue
            defaults.set(newValue, forKey: Key.lockOnSleep)
        }
    }

    public var lockOnScreenLock: Bool {
        get { values.lockOnScreenLock }
        set {
            guard values.lockOnScreenLock != newValue else { return }
            values.lockOnScreenLock = newValue
            defaults.set(newValue, forKey: Key.lockOnScreenLock)
        }
    }

    var autoLockPolicy: AutoLockPolicy {
        AutoLockPolicy(idleMinutes: values.autoLockMinutes, lockOnSleep: values.lockOnSleep, lockOnScreenLock: values.lockOnScreenLock)
    }

    // MARK: Wallet-related interface state

    /// Assets the user hid from lists, as `AssetID.description`.
    public var hiddenAssetKeys: Set<String> {
        get { values.hiddenAssetKeys }
        set {
            guard values.hiddenAssetKeys != newValue else { return }
            values.hiddenAssetKeys = newValue
            defaults.set(Array(newValue).sorted(), forKey: Key.hiddenAssets)
        }
    }

    func isHidden(_ assetID: AssetID) -> Bool {
        values.hiddenAssetKeys.contains(assetID.description)
    }

    func setHidden(_ hidden: Bool, assetID: AssetID) {
        var keys = hiddenAssetKeys
        if hidden { keys.insert(assetID.description) } else { keys.remove(assetID.description) }
        hiddenAssetKeys = keys
    }

    var selectedWalletID: String? {
        get { values.selectedWalletID }
        set {
            guard values.selectedWalletID != newValue else { return }
            values.selectedWalletID = newValue
            defaults.set(newValue, forKey: Key.selectedWallet)
        }
    }

    /// Forgets everything tied to wallets (after "Erase All Data").
    func forgetWalletState() {
        hiddenAssetKeys = []
        selectedWalletID = nil
    }
}
