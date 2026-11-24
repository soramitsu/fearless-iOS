import Foundation
import SSFUtils
import RobinHood
import SSFModels

protocol PolkaswapRemoteSubscriptionServiceProtocol {
    func subscribsToPools(
        for fromAssetId: AssetModel.Id,
        toAssetId: AssetModel.Id,
        liquiditySourceType: LiquiditySourceType,
        availablePolkaswapDex: [PolkaswapDex],
        updateClosure: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void
    )

    func subscribeToBlocks(
        updateClosure: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void
    )

    func unsubscribe()
}

final class PolkaswapRemoteSubscriptionService: PolkaswapRemoteSubscriptionServiceProtocol {
    private let connection: ChainConnection
    private let logger: LoggerProtocol
    private var subscriptions: [UInt16] = []

    init(connection: ChainConnection, logger: LoggerProtocol) {
        self.connection = connection
        self.logger = logger
    }

    func subscribeToBlocks(
        updateClosure: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void
    ) {
        do {
            let storageKeys = try createBlocksStorageKeys()
            try subscribeOn(
                storageKeys: storageKeys,
                updateClosure: updateClosure
            )
        } catch {
            logger.customError(error)
        }
    }

    func subscribsToPools(
        for fromAssetId: AssetModel.Id,
        toAssetId: AssetModel.Id,
        liquiditySourceType: LiquiditySourceType,
        availablePolkaswapDex: [PolkaswapDex],
        updateClosure: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void
    ) {
        do {
            var storageKeys: [String]
            switch liquiditySourceType {
            case .smart:
                storageKeys = try createSmartPoolStorageKeys(
                    for: fromAssetId,
                    toAssetId: toAssetId,
                    availablePolkaswapDex: availablePolkaswapDex
                )
            case .xyk:
                storageKeys = try createXykPoolStorageKeys(
                    for: fromAssetId,
                    toAssetId: toAssetId,
                    availablePolkaswapDex: availablePolkaswapDex,
                    storagePath: .polkaswapXykPool
                )
            case .tbc:
                storageKeys = try createTbcPoolStorageKeys(
                    for: fromAssetId,
                    toAssetId: toAssetId,
                    availablePolkaswapDex: availablePolkaswapDex,
                    storagePath: .polkaswapTbcPool
                )
            }
            try subscribeOn(storageKeys: storageKeys, updateClosure: updateClosure)
        } catch {
            logger.error("\(error)")
        }
    }

    func unsubscribe() {
        // cancelForIdentifier only withdraws unanswered requests; an established
        // subscription keeps running on the node until it is unsubscribed.
        subscriptions.forEach { identifier in
            do {
                try connection.unsubsribe(identifier)
            } catch {
                logger.error("\(error)")
            }
        }
        subscriptions.removeAll()
    }

    // MARK: - Private methods

    private func createBlocksStorageKeys() throws -> [String] {
        [try StorageKeyFactory()
            .createStorageKey(
                moduleName: StorageCodingPath.blockNumber.moduleName,
                storageName: StorageCodingPath.blockNumber.itemName
            ).toHex(includePrefix: true)]
    }

    private func createSmartPoolStorageKeys(
        for fromAssetId: AssetModel.Id,
        toAssetId: AssetModel.Id,
        availablePolkaswapDex: [PolkaswapDex]
    ) throws -> [String] {
        let xykStorageKeys = try createXykPoolStorageKeys(
            for: fromAssetId,
            toAssetId: toAssetId,
            availablePolkaswapDex: availablePolkaswapDex,
            storagePath: .polkaswapXykPool
        )
        let tbcStorageKeys = try createTbcPoolStorageKeys(
            for: fromAssetId,
            toAssetId: toAssetId,
            availablePolkaswapDex: availablePolkaswapDex,
            storagePath: .polkaswapTbcPool
        )
        return xykStorageKeys + tbcStorageKeys
    }

    private func createXykPoolStorageKeys(
        for fromAssetId: AssetModel.Id,
        toAssetId: AssetModel.Id,
        availablePolkaswapDex: [PolkaswapDex],
        storagePath: StorageCodingPath
    ) throws -> [String] {
        func storageKey(param1: String, param2: String) throws -> String {
            try StorageKeyFactory()
                .createStorageKey(
                    moduleName: storagePath.moduleName,
                    storageName: storagePath.itemName,
                    keys: [
                        Data(hexStringSSF: param1),
                        Data(hexStringSSF: param2)
                    ],
                    hashers: [
                        .blake128Concat,
                        .blake128Concat
                    ]
                ).toHex(includePrefix: true)
        }

        let storageKeys: [String] = try availablePolkaswapDex.map { dex in
            var keys: [String] = []
            if dex.assetId != fromAssetId {
                try keys.append(storageKey(param1: dex.assetId, param2: fromAssetId))
            }
            if dex.assetId != toAssetId {
                try keys.append(storageKey(param1: dex.assetId, param2: toAssetId))
            }
            return keys
        }.reduce([], +)
        return storageKeys
    }

    private func createTbcPoolStorageKeys(
        for fromAssetId: AssetModel.Id,
        toAssetId: AssetModel.Id,
        availablePolkaswapDex: [PolkaswapDex],
        storagePath: StorageCodingPath
    ) throws -> [String] {
        func storageKey(param1: String) throws -> String {
            try StorageKeyFactory()
                .createStorageKey(
                    moduleName: storagePath.moduleName,
                    storageName: storagePath.itemName,
                    key: Data(hexStringSSF: param1),
                    hasher: .twox64Concat
                ).toHex(includePrefix: true)
        }
        let dexStorageKeys = try availablePolkaswapDex.map { dex in
            try storageKey(param1: dex.assetId)
        }
        let destinationAssetStorageKeys: [String] = try availablePolkaswapDex.map { dex in
            var keys: [String] = []
            if dex.assetId != fromAssetId {
                try keys.append(storageKey(param1: fromAssetId))
            }
            if dex.assetId != toAssetId {
                try keys.append(storageKey(param1: toAssetId))
            }
            return keys
        }.reduce([], +)

        return dexStorageKeys + destinationAssetStorageKeys
    }

    private func subscribeOn(
        storageKeys: [String],
        updateClosure: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void
    ) throws {
        let failureClosure: (Error, Bool) -> Void = { [weak self] error, _ in
            self?.logger.error("\(error)")
        }

        // Keep every identifier, including earlier ones and those created before
        // a failure, so unsubscribe() can end each subscription.
        for storageKey in storageKeys {
            let identifier = try connection.subscribe(
                RPCMethod.storageSubscribe,
                params: [[storageKey]],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
            subscriptions.append(identifier)
        }
    }
}
