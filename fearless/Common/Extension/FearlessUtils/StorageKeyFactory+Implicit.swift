import Foundation
import FearlessUtils

extension StorageKeyFactoryProtocol {
    func accountInfoKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "System",
                             serviceName: "Account",
                             identifier: identifier,
                             hasher: Blake128Concat())
    }

    func bondedKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             serviceName: "Bonded",
                             identifier: identifier,
                             hasher: Twox64Concat())
    }

    func stakingInfoForControllerId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             serviceName: "Ledger",
                             identifier: identifier,
                             hasher: Blake128Concat())
    }

    func activeEra() throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             serviceName: "ActiveEra")
    }
 }
