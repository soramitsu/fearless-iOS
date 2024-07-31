import Foundation
import SoraKeystore
import IrohaCrypto
import SSFModels

enum SettingsKey: String {
    case selectedLocalization
    case selectedAccount
    case biometryEnabled
    case selectedConnection
    case crowdloadChainId
    case stakingAsset
    case stakingNetworkExpansion
    case referralEthereumAccount
    case selectedCurrency
    case shouldPlayAssetManagementAnimateKey
    case accountScoreEnabled
}

extension SettingsManagerProtocol {
    var biometryEnabled: Bool? {
        get {
            bool(for: SettingsKey.biometryEnabled.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.biometryEnabled.rawValue)
            } else {
                removeValue(for: SettingsKey.biometryEnabled.rawValue)
            }
        }
    }

    var selectedConnection: ConnectionItem {
        get {
            if let nodeItem = value(of: ConnectionItem.self, for: SettingsKey.selectedConnection.rawValue) {
                return nodeItem
            } else {
                return .defaultConnection
            }
        }

        set {
            set(value: newValue, for: SettingsKey.selectedConnection.rawValue)
        }
    }

    var crowdloanChainId: String? {
        get {
            string(for: SettingsKey.crowdloadChainId.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.crowdloadChainId.rawValue)
            } else {
                removeValue(for: SettingsKey.crowdloadChainId.rawValue)
            }
        }
    }

    var stakingAsset: ChainAssetId? {
        get {
            value(of: ChainAssetId.self, for: SettingsKey.stakingAsset.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.stakingAsset.rawValue)
            } else {
                removeValue(for: SettingsKey.stakingAsset.rawValue)
            }
        }
    }

    var stakingNetworkExpansion: Bool {
        get {
            bool(for: SettingsKey.stakingNetworkExpansion.rawValue) ?? true
        }

        set {
            set(value: newValue, for: SettingsKey.stakingNetworkExpansion.rawValue)
        }
    }

    var shouldRunManageAssetAnimate: Bool {
        get {
            bool(for: SettingsKey.shouldPlayAssetManagementAnimateKey.rawValue) == nil
        }
        set {
            set(value: newValue, for: SettingsKey.shouldPlayAssetManagementAnimateKey.rawValue)
        }
    }

    var accountScoreEnabled: Bool? {
        get {
            bool(for: SettingsKey.accountScoreEnabled.rawValue) ?? true
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.accountScoreEnabled.rawValue)
            } else {
                removeValue(for: SettingsKey.accountScoreEnabled.rawValue)
            }
        }
    }
}
