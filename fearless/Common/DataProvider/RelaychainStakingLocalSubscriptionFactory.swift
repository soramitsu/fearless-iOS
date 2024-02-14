import Foundation
import RobinHood
import SSFModels

protocol RelaychainStakingLocalSubscriptionFactoryProtocol {
    func getMinNominatorBondProvider(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedBigUInt>

    func getCounterForNominatorsProvider(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedU32>

    func getMaxNominatorsCountProvider(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedU32>

    func getNominationProvider(for accountId: AccountId, chainAsset: ChainAsset) throws
        -> AnyDataProvider<DecodedNomination>

    func getValidatorProvider(for accountId: AccountId, chainAsset: ChainAsset) throws
        -> AnyDataProvider<DecodedValidator>

    func getLedgerInfoProvider(for accountId: AccountId, chainAsset: ChainAsset) throws
        -> AnyDataProvider<DecodedLedgerInfo>

    func getActiveEra(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedActiveEra>

    func getCurrentEra(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedEraIndex>

    func getPayee(for accountId: AccountId, chainAsset: ChainAsset) throws
        -> AnyDataProvider<DecodedPayee>

    func getTotalReward(
        for address: AccountAddress,
        chain: ChainModel,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem>

    func getStashItemProvider(
        for address: AccountAddress
    ) -> StreamableProvider<StashItem>

    func getPoolMembersProvider(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) throws -> AnyDataProvider<DecodedPoolMember>
}

final class RelaychainStakingLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    RelaychainStakingLocalSubscriptionFactoryProtocol {
    func getPoolMembersProvider(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) throws -> AnyDataProvider<DecodedPoolMember> {
        let codingPath = StorageCodingPath.stakingPoolMembers
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

    func getMinNominatorBondProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> {
        let codingPath = StorageCodingPath.minNominatorBond
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getCounterForNominatorsProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        let codingPath = StorageCodingPath.counterForNominators
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getMaxNominatorsCountProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        let codingPath = StorageCodingPath.maxNominatorsCount
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getNominationProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> AnyDataProvider<DecodedNomination> {
        let codingPath = StorageCodingPath.nominators
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

    func getValidatorProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> AnyDataProvider<DecodedValidator> {
        let codingPath = StorageCodingPath.validatorPrefs
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

    func getLedgerInfoProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> AnyDataProvider<DecodedLedgerInfo> {
        let codingPath = StorageCodingPath.stakingLedger
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

    func getActiveEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> {
        let codingPath = StorageCodingPath.activeEra
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getCurrentEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> {
        let codingPath = StorageCodingPath.currentEra
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getPayee(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> AnyDataProvider<DecodedPayee> {
        let codingPath = StorageCodingPath.payee
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

    func getTotalReward(
        for address: AccountAddress,
        chain: ChainModel,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem> {
        guard let api = chain.externalApi?.staking else {
            throw CommonError.internal
        }

        clearIfNeeded()

        let identifier = ("reward" + api.url.absoluteString) + address

        if let provider = getProvider(for: identifier) as? SingleValueProvider<TotalRewardItem> {
            return AnySingleValueProvider(provider)
        }

        let repository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createSingleValueRepository()

        let trigger = DataProviderProxyTrigger()

        let fetcher = StakingRewardsFetcherAssembly().fetcher(for: chain)
        let source = SubqueryRewardSource(
            address: address,
            assetPrecision: assetPrecision,
            targetIdentifier: identifier,
            repository: AnyDataProviderRepository(repository),
            rewardsFetcher: fetcher,
            trigger: trigger,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let anySource = AnySingleValueProviderSource<TotalRewardItem>(source)

        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: anySource,
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        saveProvider(provider, for: identifier)

        return AnySingleValueProvider(provider)
    }

    func getStashItemProvider(
        for address: AccountAddress
    ) -> StreamableProvider<StashItem> {
        clearIfNeeded()

        let identifier = "stashItem" + address

        if let provider = getProvider(for: identifier) as? StreamableProvider<StashItem> {
            return provider
        }

        let provider = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager,
            logger: logger
        ).createStashItemProvider(for: address)

        saveProvider(provider, for: identifier)

        return provider
    }
}
