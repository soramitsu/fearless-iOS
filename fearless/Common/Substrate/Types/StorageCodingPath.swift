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

    static var erasPrefs: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "ErasValidatorPrefs")
    }

    static var controller: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "Bonded")
    }

    static var stakingLedger: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "Ledger")
    }

    static var nominators: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "Nominators")
    }

    static var validatorPrefs: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "Validators")
    }

    static var totalIssuance: StorageCodingPath {
        StorageCodingPath(moduleName: "Balances", itemName: "TotalIssuance")
    }

    static var identity: StorageCodingPath {
        StorageCodingPath(moduleName: "Identity", itemName: "IdentityOf")
    }

    static var superIdentity: StorageCodingPath {
        StorageCodingPath(moduleName: "Identity", itemName: "SuperOf")
    }

    static var slashingSpans: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "SlashingSpans")
    }

    static var unappliedSlashes: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "UnappliedSlashes")
    }
}
