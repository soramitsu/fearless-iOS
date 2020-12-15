import Foundation
import FearlessUtils

extension StorageKeyFactoryProtocol {
    func updatedDualRefCount() throws -> Data {
        try createStorageKey(moduleName: "System",
                             serviceName: "UpgradedToDualRefCount")
    }

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

    func nominators(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             serviceName: "Nominators",
                             identifier: identifier,
                             hasher: Twox64Concat())
    }

    func activeEra() throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             serviceName: "ActiveEra")
    }

    func currentEra() throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             serviceName: "CurrentEra")
    }

    func sessionIndex() throws -> Data {
        try createStorageKey(moduleName: "Session", serviceName: "CurrentIndex")
    }

    func historyDepth() throws -> Data {
        try createStorageKey(moduleName: "Staking", serviceName: "HistoryDepth")
    }

    func stakingValidatorsCount() throws -> Data {
        try createStorageKey(moduleName: "Staking", serviceName: "ValidatorCount")
    }

    func validators() throws -> Data {
        try createStorageKey(moduleName: "Session",
                             serviceName: "Validators")
    }

    func eraStakers(for eraIndex: UInt32) throws -> Data {
        let encoder = ScaleEncoder()
        try eraIndex.encode(scaleEncoder: encoder)
        let identifier = encoder.encode()

        return try createStorageKey(moduleName: "Staking",
                                    serviceName: "ErasStakers",
                                    identifier: identifier,
                                    hasher: Twox64Concat())
    }

    func wannabeValidators() throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             serviceName: "Validators")
    }
 }
