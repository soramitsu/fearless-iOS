import Foundation
import RobinHood
import IrohaCrypto
import FearlessUtils

typealias DecodedAccountInfo = ChainStorageDecodedItem<DyAccountInfo>

protocol SingleValueProviderFactoryProtocol {
    func getPriceProvider(for assetId: WalletAssetId) -> SingleValueProvider<PriceData>
    func getAccountProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> DataProvider<DecodedAccountInfo>
}

final class SingleValueProviderFactory {
    static let shared = SingleValueProviderFactory(facade: SubstrateDataStorageFacade.shared,
                                                   operationManager: OperationManagerFacade.sharedManager,
                                                   logger: Logger.shared)

    private var providers: [String: WeakWrapper] = [:]

    let facade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(facade: StorageFacadeProtocol, operationManager: OperationManagerProtocol, logger: LoggerProtocol) {
        self.facade = facade
        self.operationManager = operationManager
        self.logger = logger
    }

    private func priceIdentifier(for assetId: WalletAssetId) -> String {
        assetId.rawValue + "PriceId"
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }
}

extension SingleValueProviderFactory: SingleValueProviderFactoryProtocol {
    func getPriceProvider(for assetId: WalletAssetId) -> SingleValueProvider<PriceData> {
        clearIfNeeded()

        let identifier = priceIdentifier(for: assetId)

        if let provider = providers[identifier]?.target as? SingleValueProvider<PriceData> {
            return provider
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

        return provider
    }

    func getAccountProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> DataProvider<DecodedAccountInfo> {
        clearIfNeeded()

        let addressFactory = SS58AddressFactory()

        let addressType = try addressFactory.extractAddressType(from: address)
        let accountId = try addressFactory.accountId(fromAddress: address, type: addressType)

        let storageIdFactory = try ChainStorageIdFactory(chain: addressType.chain)

        let remoteKey = try StorageKeyFactory().accountInfoKeyForId(accountId)
        let localKey = storageIdFactory.createIdentifier(for: remoteKey)

        if let dataProvider = providers[localKey]?.target as? DataProvider<DecodedAccountInfo> {
            return dataProvider
        }

        let repository = InMemoryDataProviderRepository<ChainStorageDecodedItem<DyAccountInfo>>()

        let streamableProviderFactory = SubstrateDataProviderFactory(facade: facade,
                                                                     operationManager: operationManager,
                                                                     logger: logger)
        let streamableProvider = streamableProviderFactory.createStorageProvider(for: localKey)

        let trigger = DataProviderProxyTrigger()
        let source: StorageProviderSource<DyAccountInfo> =
            StorageProviderSource(itemIdentifier: localKey,
                                  codingPath: .account,
                                  runtimeService: runtimeService,
                                  provider: streamableProvider,
                                  trigger: trigger)

        let dataProvider = DataProvider(source: AnyDataProviderSource(source),
                                        repository: AnyDataProviderRepository(repository),
                                        updateTrigger: trigger)

        providers[localKey] = WeakWrapper(target: dataProvider)

        return dataProvider
    }
}
