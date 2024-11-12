import Foundation
import RobinHood

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
