import Foundation
import RobinHood

protocol WalletLocalSubscriptionFactoryProtocol {
    func getAccountProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedAccountInfo>

    func getOrmlAccountProvider(
        for accountId: AccountId,
        chain: ChainModel
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
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedAccountInfo> {
        let codingPath = StorageCodingPath.account

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getOrmlAccountProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) throws -> AnyDataProvider<DecodedOrmlAccountInfo> {
        let codingPath = StorageCodingPath.tokens

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            accountId: accountId,
            chainId: chain.chainId,
            tokenSymbol: chain.tokenSymbol
        )

        return try getDataProvider(
            for: localKey,
            chainId: chain.chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }
}
