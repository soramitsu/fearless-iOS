import Foundation
import RobinHood

protocol WalletLocalSubscriptionFactoryProtocol {
    func getAccountProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> AnyDataProvider<DecodedAccountInfo>

    func getOrmlAccountProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> AnyDataProvider<DecodedOrmlAccountInfo>
}

final class WalletLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    WalletLocalSubscriptionFactoryProtocol {
    static let shared = WalletLocalSubscriptionFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        storageFacade: SubstrateDataStorageFacade.shared,
        operationManager: OperationManagerFacade.sharedManager,
        logger: Logger.shared
    )

    func getAccountProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> AnyDataProvider<DecodedAccountInfo> {
        let codingPath = StorageCodingPath.account

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainAsset.chain.chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getOrmlAccountProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> AnyDataProvider<DecodedOrmlAccountInfo> {
        let codingPath = StorageCodingPath.tokens

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainAsset.chain.chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }
}
