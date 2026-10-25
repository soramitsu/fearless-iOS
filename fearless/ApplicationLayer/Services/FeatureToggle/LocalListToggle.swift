import Foundation
import SSFModels

struct LocalListToggle: Codable {
    let key: String
    let title: String
    let description: String
    var storageValue: Bool

    func toggle() -> Self {
        LocalListToggle(
            key: key,
            title: title,
            description: description,
            storageValue: !storageValue
        )
    }
}

extension LocalListToggle {
    static let chains = LocalListToggle(
        key: "0",
        title: "Chains list env",
        description: "is chains_dev.json",
        storageValue: true
    )

    static let tonEnv = LocalListToggle(
        key: "1",
        title: "Ton environment",
        description: "is testnet",
        storageValue: false
    )
}

enum TonChainSelection {
    static let testnetChainId = "-3"
    static let mainnetChainId = "-239"

    static func selectedChainId(isTestnetEnabled: Bool) -> ChainModel.Id {
        isTestnetEnabled ? testnetChainId : mainnetChainId
    }

    static func selectedChainId() -> ChainModel.Id {
        selectedChainId(isTestnetEnabled: LocalToggleService.shared.tonEnvListToggle.storageValue)
    }

    static func matchesSelectedEnvironment(chain: ChainModel, isTestnetEnabled: Bool) -> Bool {
        let isTestnetChain = (chain.options ?? []).contains(.testnet)
        return isTestnetEnabled == isTestnetChain
    }
}
