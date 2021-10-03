import Foundation
import RobinHood

protocol StakingLocalSubscriptionFactoryProtocol {
    func getMinNominatorBondProvider(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedBigUInt>

    func getCounterForNominatorsProvider(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedU32>

    func getMaxNominatorsCountProvider(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedU32>

    func getNominationProvider(for accountId: AccountId, chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedNomination>

    func getValidatorProvider(for accountId: AccountId, chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedValidator>

    func getLedgerInfoProvider(for accountId: AccountId, chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedLedgerInfo>

    func getActiveEra(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedActiveEra>

    func getCurrentEra(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedEraIndex>

    func getPayee(for accountId: AccountId, chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedPayee>

    func getTotalReward(
        for address: AccountAddress,
        api: ChainModel.ExternalApi,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem>

    func getStashItemProvider(
        for address: AccountAddress
    ) -> StreamableProvider<StashItem>
}

final class StakingLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    StakingLocalSubscriptionFactoryProtocol {
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
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedNomination> {
        let codingPath = StorageCodingPath.nominators
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

    func getValidatorProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedValidator> {
        let codingPath = StorageCodingPath.validatorPrefs
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

    func getLedgerInfoProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedLedgerInfo> {
        let codingPath = StorageCodingPath.stakingLedger
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
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedPayee> {
        let codingPath = StorageCodingPath.payee
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

    func getTotalReward(
        for address: AccountAddress,
        api: ChainModel.ExternalApi,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem> {
        clearIfNeeded()

        let identifier = ("reward" + api.url.absoluteString) + address

        if let provider = getProvider(for: identifier) as? SingleValueProvider<TotalRewardItem> {
            return AnySingleValueProvider(provider)
        }

        let repository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createSingleValueRepository()

        let trigger = DataProviderProxyTrigger()

        let operationFactory = SubqueryRewardOperationFactory(url: api.url)

        let source = SubqueryRewardSource(
            address: address,
            assetPrecision: assetPrecision,
            targetIdentifier: identifier,
            repository: AnyDataProviderRepository(repository),
            operationFactory: operationFactory,
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
