import Foundation
import RobinHood
import IrohaCrypto
import FearlessUtils

typealias DecodedAccountInfo = ChainStorageDecodedItem<DyAccountInfo>
typealias DecodedElectionStatus = ChainStorageDecodedItem<ElectionStatus>
typealias DecodedNomination = ChainStorageDecodedItem<Nomination>
typealias DecodedValidator = ChainStorageDecodedItem<ValidatorPrefs>
typealias DecodedLedgerInfo = ChainStorageDecodedItem<DyStakingLedger>
typealias DecodedActiveEra = ChainStorageDecodedItem<ActiveEraInfo>

protocol SingleValueProviderFactoryProtocol {
    func getPriceProvider(for assetId: WalletAssetId) -> AnySingleValueProvider<PriceData>
    func getAccountProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedAccountInfo>
    func getElectionStatusProvider(chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedElectionStatus>
    func getNominationProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedNomination>
    func getValidatorProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedValidator>
    func getLedgerInfoProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedLedgerInfo>
    func getActiveEra(for chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedActiveEra>
}

final class SingleValueProviderFactory {
    static let shared = SingleValueProviderFactory(facade: SubstrateDataStorageFacade.shared,
                                                   operationManager: OperationManagerFacade.sharedManager,
                                                   logger: Logger.shared)

    private var providers: [String: WeakWrapper] = [:]

    let facade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol
    let stremableProviderFactory: SubstrateDataProviderFactoryProtocol

    init(facade: StorageFacadeProtocol, operationManager: OperationManagerProtocol, logger: LoggerProtocol) {
        self.facade = facade
        self.operationManager = operationManager
        self.logger = logger
        self.stremableProviderFactory = SubstrateDataProviderFactory(facade: facade,
                                                                     operationManager: operationManager,
                                                                     logger: logger)
    }

    private func priceIdentifier(for assetId: WalletAssetId) -> String {
        assetId.rawValue + "PriceId"
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }

    private func getDataProvider<T>(for remoteKey: Data,
                                    path: StorageCodingPath,
                                    runtimeService: RuntimeCodingServiceProtocol,
                                    localKeyFactory: ChainStorageIdFactoryProtocol,
                                    shouldUseFallback: Bool)
    -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {
        clearIfNeeded()

        let localKey = localKeyFactory.createIdentifier(for: remoteKey)

        if let dataProvider = providers[localKey]?.target as? DataProvider<ChainStorageDecodedItem<T>> {
            return AnyDataProvider(dataProvider)
        }

        let repository = InMemoryDataProviderRepository<ChainStorageDecodedItem<T>>()

        let streamableProvider = stremableProviderFactory.createStorageProvider(for: localKey)

        let trigger = DataProviderProxyTrigger()
        let source: StorageProviderSource<T> =
            StorageProviderSource(itemIdentifier: localKey,
                                  codingPath: path,
                                  runtimeService: runtimeService,
                                  provider: streamableProvider,
                                  trigger: trigger,
                                  shouldUseFallback: shouldUseFallback)

        let dataProvider = DataProvider(source: AnyDataProviderSource(source),
                                        repository: AnyDataProviderRepository(repository),
                                        updateTrigger: trigger)

        providers[localKey] = WeakWrapper(target: dataProvider)

        return AnyDataProvider(dataProvider)
    }

    private func getAccountIdKeyedProvider<T>(address: String,
                                              path: StorageCodingPath,
                                              hasher: StorageHasher,
                                              runtimeService: RuntimeCodingServiceProtocol,
                                              shouldUseFallback: Bool) throws
    -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {

        let addressFactory = SS58AddressFactory()

        let addressType = try addressFactory.extractAddressType(from: address)
        let accountId = try addressFactory.accountId(fromAddress: address, type: addressType)

        let storageIdFactory = try ChainStorageIdFactory(chain: addressType.chain)

        let remoteKey = try StorageKeyFactory().createStorageKey(moduleName: path.moduleName,
                                                                 storageName: path.itemName,
                                                                 key: accountId,
                                                                 hasher: hasher)

        return getDataProvider(for: remoteKey,
                               path: path,
                               runtimeService: runtimeService,
                               localKeyFactory: storageIdFactory,
                               shouldUseFallback: shouldUseFallback)
    }

    private func getProviderForChain<T>(_ chain: Chain,
                                        path: StorageCodingPath,
                                        runtimeService: RuntimeCodingServiceProtocol,
                                        shouldUseFallback: Bool) throws
    -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {
        let storageIdFactory = try ChainStorageIdFactory(chain: chain)
        let remoteKey = try StorageKeyFactory().createStorageKey(moduleName: path.moduleName,
                                                                 storageName: path.itemName)

        return getDataProvider(for: remoteKey,
                               path: path,
                               runtimeService: runtimeService,
                               localKeyFactory: storageIdFactory,
                               shouldUseFallback: true)
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
        let provider = SingleValueProvider(targetIdentifier: identifier,
                                           source: AnySingleValueProviderSource(source),
                                           repository: AnyDataProviderRepository(repository),
                                           updateTrigger: trigger)

        providers[identifier] = WeakWrapper(target: provider)

        return AnySingleValueProvider(provider)
    }

    func getAccountProvider(for address: String,
                            runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedAccountInfo> {
        try getAccountIdKeyedProvider(address: address,
                                      path: .account,
                                      hasher: .blake128Concat,
                                      runtimeService: runtimeService,
                                      shouldUseFallback: false)
    }

    func getElectionStatusProvider(chain: Chain,
                                   runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedElectionStatus> {
        try getProviderForChain(chain,
                                path: .electionStatus,
                                runtimeService: runtimeService,
                                shouldUseFallback: true)
    }

    func getNominationProvider(for address: String,
                               runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedNomination> {
        try getAccountIdKeyedProvider(address: address,
                                      path: .nominators,
                                      hasher: .twox64Concat,
                                      runtimeService: runtimeService,
                                      shouldUseFallback: false)
    }

    func getValidatorProvider(for address: String,
                              runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedValidator> {
        try getAccountIdKeyedProvider(address: address,
                                      path: .validatorPrefs,
                                      hasher: .twox64Concat,
                                      runtimeService: runtimeService,
                                      shouldUseFallback: false)
    }

    func getLedgerInfoProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedLedgerInfo> {
        try getAccountIdKeyedProvider(address: address,
                                      path: .stakingLedger,
                                      hasher: .blake128Concat,
                                      runtimeService: runtimeService,
                                      shouldUseFallback: false)
    }

    func getActiveEra(for chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedActiveEra> {
        try getProviderForChain(chain,
                                path: .activeEra,
                                runtimeService: runtimeService,
                                shouldUseFallback: true)
    }
}
