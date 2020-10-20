import Foundation
import FearlessUtils

extension StorageKeyFactoryProtocol {
    func accountInfoKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "System",
                             serviceName: "Account",
                             identifier: identifier)
    }

    func bondedKeyForId(_ identifier: Data) throws -> Data {
        let serviceKey = try createStorageKey(moduleName: "Staking",
                                              serviceName: "Bonded")

        return serviceKey + identifier.twox64Concat()
    }

    func stakingInfoForControllerId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             serviceName: "Ledger",
                             identifier: identifier)
    }

    func activeEra() throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             serviceName: "ActiveEra")
    }
 }
