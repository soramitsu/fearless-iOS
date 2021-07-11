import Foundation
@testable import fearless
import FearlessUtils
import IrohaCrypto
import RobinHood

final class MultiAssetMockSubscriptionFactory: WebSocketSubscriptionFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    let storageKeyFactory = StorageKeyFactory()
    let addressFactory = SS58AddressFactory()
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    let logger = Logger.shared

    let runtimeService: RuntimeCodingServiceProtocol
    let providerFactory: SubstrateDataProviderFactoryProtocol

    let serviceId: String

    init(
        serviceId: String,
        storageFacade: StorageFacadeProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.serviceId = serviceId
        self.storageFacade = storageFacade
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.eventCenter = eventCenter

        providerFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager
        )
    }

    func createSubscriptions(
        address: String,
        type: SNAddressType,
        engine: JSONRPCEngine
    ) throws -> [WebSocketSubscribing] {
        let accountId: Data

        if let ss58AccountId = try? addressFactory.accountId(fromAddress: address, type: type) {
            accountId = ss58AccountId
        } else {
            accountId = try Data(hexString: address)
        }

        let localStorageIdFactory = try ChainStorageIdFactory(chain: type.chain)

        let childSubscriptionFactory = ChildSubscriptionFactory(
            storageFacade: storageFacade,
            operationManager: operationManager,
            eventCenter: eventCenter,
            localKeyFactory: localStorageIdFactory,
            logger: logger
        )

        let blockSubscription = try createBlockNumberSubscription(
            childSubscriptionFactory,
            serviceId: serviceId,
            networkType: type,
            logger: logger
        )

        let runtimeSubscription = createRuntimeVersionSubscription(engine: engine, networkType: type)

        let accountSubscription = try createAccountSubscription(
            childSubscriptionFactory,
            accountId: accountId,
            serviceId: serviceId,
            networkType: type,
            logger: logger
        )

        let container = StorageSubscriptionContainer(
            engine: engine,
            children: [blockSubscription, accountSubscription],
            logger: Logger.shared
        )

        return [
            container,
            runtimeSubscription
        ]
    }

    private func createRuntimeVersionSubscription(
        engine: JSONRPCEngine,
        networkType: SNAddressType
    ) -> RuntimeVersionSubscription {
        let chain = networkType.chain

        let filter = NSPredicate.filterRuntimeMetadataItemsBy(identifier: chain.genesisHash)
        let storage: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository(filter: filter)

        return RuntimeVersionSubscription(
            chain: chain,
            storage: AnyDataProviderRepository(storage),
            engine: engine,
            operationManager: operationManager,
            logger: logger
        )
    }

    private func createAccountSubscription(
        _ factory: ChildSubscriptionFactoryProtocol,
        accountId: Data,
        serviceId: String,
        networkType: SNAddressType,
        logger: LoggerProtocol
    ) throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.accountInfoKeyForId(accountId)

        logger.info("Will create account subscription \(networkType)")

        return factory.createCustomHandlingSubscription(remoteKey: remoteStorageKey) { chainItem in
            if
                let data = chainItem.item?.data {
                self.logAccountInfo(for: data, networkType: networkType)
            } else {
                logger.info("Service \(serviceId) (\(networkType)): did receive no account")
            }
        }
    }

    private func createBlockNumberSubscription(
        _ factory: ChildSubscriptionFactoryProtocol,
        serviceId: String,
        networkType: SNAddressType,
        logger: LoggerProtocol
    ) throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.key(from: .blockNumber)

        logger.info("Will create block subscription \(networkType)")

        return factory.createCustomHandlingSubscription(remoteKey: remoteStorageKey) { chainItem in
            if
                let data = chainItem.item?.data,
                let decoder = try? ScaleDecoder(data: data),
                let blockNumber = try? BlockNumber(scaleDecoder: decoder) {
                logger.info("Service \(serviceId) (\(networkType)): did receive block \(blockNumber)")
            } else {
                logger.info("Service \(serviceId) (\(networkType)): did receive no block")
            }
        }
    }

    private func logAccountInfo(for data: Data, networkType: SNAddressType) {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let decodingOperation: StorageDecodingOperation<AccountInfo> =
            StorageDecodingOperation(path: .account, data: data)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try coderFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.completionBlock = {
            do {
                let accountInfo = try decodingOperation.extractNoCancellableResultData()
                self.logger.info("Account info (\(networkType)): \(accountInfo)")
            } catch {
                self.logger.error("Account (\(networkType)) decoding error: \(error)")
            }
        }

        decodingOperation.addDependency(coderFactoryOperation)

        operationManager.enqueue(operations: [coderFactoryOperation, decodingOperation], in: .transient)
    }
}
