import Foundation
import SSFUtils
import RobinHood
import SSFRuntimeCodingService

enum ChainStakingSettingsType {
    case `default`
    case sora
    case reef
}

protocol ChainStakingSettings {
    var rewardAssetName: String? { get }
    var type: ChainStakingSettingsType { get }

    func rewardDestinationArg(accountId: AccountId) -> RewardDestinationArg
    func multiAddress(accountId: AccountId) -> MultiAddress

    func queryItems<T>(
        engine: JSONRPCEngine,
        keyParams: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        using requestFactory: StorageRequestFactoryProtocol
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable

    func queryItems<T>(
        engine: JSONRPCEngine,
        keyParams: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        using requestFactory: AsyncStorageRequestFactory
    ) -> AwaitOperation<[StorageResponse<T>]> where T: Decodable
}

struct DefaultRelaychainChainStakingSettings: ChainStakingSettings {
    func queryItems<T>(
        engine: SSFUtils.JSONRPCEngine,
        keyParams: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        using requestFactory: StorageRequestFactoryProtocol
    ) -> RobinHood.CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        requestFactory.queryItems(engine: engine, keyParams: keyParams, factory: factory, storagePath: storagePath)
    }

    func queryItems<T>(engine: JSONRPCEngine, keyParams: @escaping () throws -> [Data], factory: @escaping () throws -> RuntimeCoderFactoryProtocol, storagePath: StorageCodingPath, using requestFactory: AsyncStorageRequestFactory) -> AwaitOperation<[StorageResponse<T>]> where T: Decodable {
        AwaitOperation {
            try await requestFactory.queryItems(
                engine: engine,
                keyParams: keyParams(),
                factory: factory(),
                storagePath: storagePath
            )
        }
    }

    var rewardAssetName: String? {
        nil
    }

    func multiAddress(accountId: AccountId) -> MultiAddress {
        .accoundId(accountId)
    }

    var type: ChainStakingSettingsType {
        .default
    }

    func rewardDestinationArg(accountId: AccountId) -> RewardDestinationArg {
        .account(accountId)
    }
}

struct SoraChainStakingSettings: ChainStakingSettings {
    func queryItems<T>(
        engine: SSFUtils.JSONRPCEngine,
        keyParams: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        using requestFactory: StorageRequestFactoryProtocol
    ) -> RobinHood.CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        requestFactory.queryItems(engine: engine, keyParams: keyParams, factory: factory, storagePath: storagePath)
    }

    func queryItems<T>(engine: JSONRPCEngine, keyParams: @escaping () throws -> [Data], factory: @escaping () throws -> RuntimeCoderFactoryProtocol, storagePath: StorageCodingPath, using requestFactory: AsyncStorageRequestFactory) -> AwaitOperation<[StorageResponse<T>]> where T: Decodable {
        AwaitOperation {
            try await requestFactory.queryItems(
                engine: engine,
                keyParams: keyParams(),
                factory: factory(),
                storagePath: storagePath
            )
        }
    }

    var rewardAssetName: String? {
        "val"
    }

    func multiAddress(accountId: AccountId) -> MultiAddress {
        .accountTo(accountId)
    }

    var type: ChainStakingSettingsType {
        .sora
    }

    func rewardDestinationArg(accountId: AccountId) -> RewardDestinationArg {
        .account(accountId)
    }
}

struct ReefChainStakingSettings: ChainStakingSettings {
    func queryItems<T>(
        engine: SSFUtils.JSONRPCEngine,
        keyParams: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        using requestFactory: StorageRequestFactoryProtocol
    ) -> RobinHood.CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        let params = { try keyParams().compactMap { $0.toHex() } }
        return requestFactory.queryItems(engine: engine, keyParams: params, factory: factory, storagePath: storagePath)
    }

    func queryItems<T>(engine: JSONRPCEngine, keyParams: @escaping () throws -> [Data], factory: @escaping () throws -> RuntimeCoderFactoryProtocol, storagePath: StorageCodingPath, using requestFactory: AsyncStorageRequestFactory) -> AwaitOperation<[StorageResponse<T>]> where T: Decodable {
        let params = { try keyParams().compactMap { $0.toHex() } }
        return AwaitOperation {
            try await requestFactory.queryItems(
                engine: engine,
                keyParams: params(),
                factory: factory(),
                storagePath: storagePath
            )
        }
    }

    var rewardAssetName: String? {
        nil
    }

    func multiAddress(accountId: AccountId) -> MultiAddress {
        .indexedString(accountId)
    }

    var type: ChainStakingSettingsType {
        .reef
    }

    func rewardDestinationArg(accountId: AccountId) -> RewardDestinationArg {
        .address(accountId.toHexString())
    }
}
