import Foundation

struct StorageCodingPath {
    let moduleName: String
    let itemName: String
}

extension StorageCodingPath {
    static var account: StorageCodingPath {
        StorageCodingPath(moduleName: "System", itemName: "Account")
    }

    static var activeEra: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "ActiveEra")
    }

    static var erasStakers: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "ErasStakers")
    }

    static var validatorPrefs: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "Validators")
    }
}
