import Foundation
import RobinHood
import IrohaCrypto
import FearlessUtils
import BigInt

typealias DecodedAccountInfo = ChainStorageDecodedItem<AccountInfo>
typealias DecodedElectionStatus = ChainStorageDecodedItem<ElectionStatus>
typealias DecodedBigUInt = ChainStorageDecodedItem<StringScaleMapper<BigUInt>>
typealias DecodedU32 = ChainStorageDecodedItem<StringScaleMapper<UInt32>>
typealias DecodedNomination = ChainStorageDecodedItem<Nomination>
typealias DecodedValidator = ChainStorageDecodedItem<ValidatorPrefs>
typealias DecodedLedgerInfo = ChainStorageDecodedItem<StakingLedger>
typealias DecodedActiveEra = ChainStorageDecodedItem<ActiveEraInfo>
typealias DecodedPayee = ChainStorageDecodedItem<RewardDestinationArg>
typealias DecodedBlockNumber = ChainStorageDecodedItem<StringScaleMapper<BlockNumber>>
typealias DecodedCrowdloanFunds = ChainStorageDecodedItem<CrowdloanFunds>

protocol SingleValueProviderFactoryProtocol {
    func getPriceProvider(for assetId: WalletAssetId) -> AnySingleValueProvider<PriceData>
    func getTotalReward(for address: String, assetId: WalletAssetId) throws
        -> AnySingleValueProvider<TotalRewardItem>
    func getAccountProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedAccountInfo>
    func getElectionStatusProvider(chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedElectionStatus>
    func getMinNominatorBondProvider(chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedBigUInt>
    func getMaxNominatorsCountProvider(chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedU32>
    func getNominationProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedNomination>
    func getValidatorProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedValidator>
    func getLedgerInfoProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedLedgerInfo>
    func getActiveEra(for chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedActiveEra>
    func getPayee(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedPayee>
    func getBlockNumber(for chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedBlockNumber>

    func getJson<T: Codable & Equatable>(for url: URL) -> AnySingleValueProvider<T>

    func getCrowdloanFunds(
        for paraId: ParaId,
        connection: ConnectionItem,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedCrowdloanFunds>
}

final class SingleValueProviderFactory {
    static let shared = SingleValueProviderFactory(
        facade: SubstrateDataStorageFacade.shared,
        operationManager: OperationManagerFacade.sharedManager,
        logger: Logger.shared
    )

    private var providers: [String: WeakWrapper] = [:]

    let facade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol
    let stremableProviderFactory: SubstrateDataProviderFactoryProtocol

    init(facade: StorageFacadeProtocol, operationManager: OperationManagerProtocol, logger: LoggerProtocol) {
        self.facade = facade
        self.operationManager = operationManager
        self.logger = logger
        stremableProviderFactory = SubstrateDataProviderFactory(
            facade: facade,
            operationManager: operationManager,
            logger: logger
        )
    }

    private func priceIdentifier(for assetId: WalletAssetId) -> String {
        assetId.rawValue + "PriceId"
    }

    private func totalRewardIdentifier(
        for address: String,
        assetId: WalletAssetId,
        supportsSubquery: Bool
    ) -> String {
        let methodName = supportsSubquery ? "subquery" : "subscan"

        return assetId.rawValue + address + "Reward" + methodName
    }

    private func electionStatusId(for chain: Chain) -> String {
        chain.genesisHash + "ElectionStatus"
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }

    private func getDataProvider<T>(
        for remoteKey: Data,
        path: StorageCodingPath,
        runtimeService: RuntimeCodingServiceProtocol,
        localKeyFactory: ChainStorageIdFactoryProtocol,
        shouldUseFallback: Bool
    ) -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {
        clearIfNeeded()

        let localKey = localKeyFactory.createIdentifier(for: remoteKey)

        if let dataProvider = providers[localKey]?.target as? DataProvider<ChainStorageDecodedItem<T>> {
            return AnyDataProvider(dataProvider)
        }

        let repository = InMemoryDataProviderRepository<ChainStorageDecodedItem<T>>()

        let streamableProvider = stremableProviderFactory.createStorageProvider(for: localKey)

        let trigger = DataProviderProxyTrigger()
        let source: StorageProviderSource<T> =
            StorageProviderSource(
                itemIdentifier: localKey,
                codingPath: path,
                runtimeService: runtimeService,
                provider: streamableProvider,
                trigger: trigger,
                shouldUseFallback: shouldUseFallback
            )

        let dataProvider = DataProvider(
            source: AnyDataProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        providers[localKey] = WeakWrapper(target: dataProvider)

        return AnyDataProvider(dataProvider)
    }

    private func getAccountIdKeyedProvider<T>(
        address: String,
        path: StorageCodingPath,
        hasher: StorageHasher,
        runtimeService: RuntimeCodingServiceProtocol,
        shouldUseFallback: Bool
    ) throws
        -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {
        let addressFactory = SS58AddressFactory()

        let addressType = try addressFactory.extractAddressType(from: address)
        let accountId = try addressFactory.accountId(fromAddress: address, type: addressType)

        let storageIdFactory = try ChainStorageIdFactory(chain: addressType.chain)

        let remoteKey = try StorageKeyFactory().createStorageKey(
            moduleName: path.moduleName,
            storageName: path.itemName,
            key: accountId,
            hasher: hasher
        )

        return getDataProvider(
            for: remoteKey,
            path: path,
            runtimeService: runtimeService,
            localKeyFactory: storageIdFactory,
            shouldUseFallback: shouldUseFallback
        )
    }

    private func getProviderForChain<T>(
        _ chain: Chain,
        path: StorageCodingPath,
        runtimeService: RuntimeCodingServiceProtocol,
        shouldUseFallback: Bool
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {
        let storageIdFactory = try ChainStorageIdFactory(chain: chain)
        let remoteKey = try StorageKeyFactory().createStorageKey(
            moduleName: path.moduleName,
            storageName: path.itemName
        )

        return getDataProvider(
            for: remoteKey,
            path: path,
            runtimeService: runtimeService,
            localKeyFactory: storageIdFactory,
            shouldUseFallback: shouldUseFallback
        )
    }
}

extension SingleValueProviderFactory: SingleValueProviderFactoryProtocol {
    func getPriceProvider(for assetId: WalletAssetId) -> AnySingleValueProvider<PriceData> {
        clearIfNeeded()

        let identifier = priceIdentifier(for: assetId)

        if let provider = providers[identifier]?.target as? SingleValueProvider<PriceData> {
            return AnySingleValueProvider(provider)
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            facade.createRepository()

        let source = SubscanPriceSource(assetId: assetId)

        let trigger: DataProviderEventTrigger = [.onAddObserver, .onInitialization]
        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        providers[identifier] = WeakWrapper(target: provider)

        return AnySingleValueProvider(provider)
    }

    func getTotalReward(
        for address: String,
        assetId: WalletAssetId
    ) throws -> AnySingleValueProvider<TotalRewardItem> {
        clearIfNeeded()

        let addressFactory = SS58AddressFactory()
        let type = try addressFactory.extractAddressType(from: address)
        let chain = type.chain

        let identifier = totalRewardIdentifier(
            for: address,
            assetId: assetId,
            supportsSubquery: chain.totalRewardURL != nil
        )

        if let provider = providers[identifier]?.target as? SingleValueProvider<TotalRewardItem> {
            return AnySingleValueProvider(provider)
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            facade.createRepository()

        let trigger = DataProviderProxyTrigger()

        let anySource: AnySingleValueProviderSource<TotalRewardItem> = {
            if let url = chain.totalRewardURL {
                let source = SubqueryRewardSource(address: address, url: url, chain: chain)
                return AnySingleValueProviderSource(source)
            } else {
                let source = SubscanRewardSource(
                    address: address,
                    assetId: assetId,
                    chain: chain,
                    targetIdentifier: identifier,
                    repository: AnyDataProviderRepository(repository),
                    operationFactory: SubscanOperationFactory(),
                    trigger: trigger,
                    operationManager: operationManager,
                    logger: logger
                )
                return AnySingleValueProviderSource(source)
            }
        }()

        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: anySource,
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        providers[identifier] = WeakWrapper(target: provider)

        return AnySingleValueProvider(provider)
    }

    func getAccountProvider(
        for address: String,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws
        -> AnyDataProvider<DecodedAccountInfo> {
        try getAccountIdKeyedProvider(
            address: address,
            path: .account,
            hasher: .blake128Concat,
            runtimeService: runtimeService,
            shouldUseFallback: false
        )
    }

    func getElectionStatusProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws
        -> AnyDataProvider<DecodedElectionStatus> {
        clearIfNeeded()

        let localKey = electionStatusId(for: chain)

        if let existingProvider = providers[localKey]?.target as? DataProvider<DecodedElectionStatus> {
            return AnyDataProvider(existingProvider)
        }

        let storageIdFactory = try ChainStorageIdFactory(chain: chain)

        let repository = InMemoryDataProviderRepository<DecodedElectionStatus>()

        let trigger = DataProviderProxyTrigger()

        let source = ElectionStatusSource(
            itemIdentifier: localKey,
            localKeyFactory: storageIdFactory,
            runtimeService: runtimeService,
            providerFactory: stremableProviderFactory,
            operationManager: operationManager,
            trigger: trigger,
            logger: logger
        )

        let dataProvider = DataProvider(
            source: AnyDataProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        providers[localKey] = WeakWrapper(target: dataProvider)

        return AnyDataProvider(dataProvider)
    }

    func getNominationProvider(
        for address: String,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws
        -> AnyDataProvider<DecodedNomination> {
        try getAccountIdKeyedProvider(
            address: address,
            path: .nominators,
            hasher: .twox64Concat,
            runtimeService: runtimeService,
            shouldUseFallback: false
        )
    }

    func getValidatorProvider(
        for address: String,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws
        -> AnyDataProvider<DecodedValidator> {
        try getAccountIdKeyedProvider(
            address: address,
            path: .validatorPrefs,
            hasher: .twox64Concat,
            runtimeService: runtimeService,
            shouldUseFallback: false
        )
    }

    func getLedgerInfoProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedLedgerInfo> {
        try getAccountIdKeyedProvider(
            address: address,
            path: .stakingLedger,
            hasher: .blake128Concat,
            runtimeService: runtimeService,
            shouldUseFallback: false
        )
    }

    func getActiveEra(for chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws
        -> AnyDataProvider<DecodedActiveEra> {
        try getProviderForChain(
            chain,
            path: .activeEra,
            runtimeService: runtimeService,
            shouldUseFallback: true
        )
    }

    func getMinNominatorBondProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getProviderForChain(
            chain,
            path: .minNominatorBond,
            runtimeService: runtimeService,
            shouldUseFallback: false
        )
    }

    func getMaxNominatorsCountProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> AnyDataProvider<DecodedU32> {
        try getProviderForChain(
            chain,
            path: .maxNominatorsCount,
            runtimeService: runtimeService,
            shouldUseFallback: false
        )
    }

    func getPayee(
        for address: String,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> AnyDataProvider<DecodedPayee> {
        try getAccountIdKeyedProvider(
            address: address,
            path: .payee,
            hasher: .twox64Concat,
            runtimeService: runtimeService,
            shouldUseFallback: false
        )
    }

    func getBlockNumber(
        for chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> AnyDataProvider<DecodedBlockNumber> {
        try getProviderForChain(
            chain,
            path: .blockNumber,
            runtimeService: runtimeService,
            shouldUseFallback: true
        )
    }

    func getJson<T: Codable & Equatable>(for url: URL) -> AnySingleValueProvider<T> {
        let localKey = url.absoluteString

        if let provider = providers[localKey]?.target as? SingleValueProvider<T> {
            return AnySingleValueProvider(provider)
        }

        let source = JsonSingleProviderSource<T>(url: url)

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = facade.createRepository()

        let singleValueProvider = SingleValueProvider(
            targetIdentifier: localKey,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository)
        )

        providers[localKey] = WeakWrapper(target: singleValueProvider)

        return AnySingleValueProvider(singleValueProvider)
    }

    func getCrowdloanFunds(
        for paraId: ParaId,
        connection: ConnectionItem,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedCrowdloanFunds> {
        clearIfNeeded()

        let codingPath = StorageCodingPath.crowdloanFunds
        let localKey = connection.identifier + codingPath.moduleName + codingPath.itemName + String(paraId)

        if let dataProvider = providers[localKey]?.target as? DataProvider<DecodedCrowdloanFunds> {
            return AnyDataProvider(dataProvider)
        }

        let repository = InMemoryDataProviderRepository<DecodedCrowdloanFunds>()

        let trigger = DataProviderProxyTrigger()
        let source: WebSocketProviderSource<CrowdloanFunds> = WebSocketProviderSource(
            itemIdentifier: localKey,
            codingPath: codingPath,
            keyOperationClosure: { factoryClosure in
                let operation = MapKeyEncodingOperation(
                    path: .crowdloanFunds,
                    storageKeyFactory: StorageKeyFactory(),
                    keyParams: [StringScaleMapper(value: paraId)]
                )

                operation.configurationBlock = {
                    do {
                        operation.codingFactory = try factoryClosure()
                    } catch {
                        operation.result = .failure(error)
                    }
                }

                return operation
            },
            runtimeService: runtimeService,
            engine: engine,
            trigger: trigger,
            operationManager: operationManager
        )

        let dataProvider = DataProvider(
            source: AnyDataProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        providers[localKey] = WeakWrapper(target: dataProvider)

        return AnyDataProvider(dataProvider)
    }
}
