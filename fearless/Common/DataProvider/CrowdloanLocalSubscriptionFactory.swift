import Foundation
import RobinHood
import FearlessUtils

protocol CrowdloanLocalSubscriptionFactoryProtocol {
    func getBlockNumberProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBlockNumber>
    func getCrowdloanFundsProvider(
        for paraId: ParaId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedCrowdloanFunds>
}

final class CrowdloanLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    CrowdloanLocalSubscriptionFactoryProtocol {
    func getBlockNumberProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBlockNumber> {
        let codingPath = StorageCodingPath.blockNumber
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getCrowdloanFundsProvider(
        for paraId: ParaId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedCrowdloanFunds> {
        clearIfNeeded()

        let codingPath = StorageCodingPath.crowdloanFunds

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            encodableElement: paraId,
            chainId: chainId
        )

        if let dataProvider = getProvider(for: localKey) as? DataProvider<DecodedCrowdloanFunds> {
            return AnyDataProvider(dataProvider)
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let repository = InMemoryDataProviderRepository<DecodedCrowdloanFunds>()

        let trigger = DataProviderProxyTrigger()
        let source: WebSocketProviderSource<CrowdloanFunds> = WebSocketProviderSource(
            itemIdentifier: localKey,
            codingPath: codingPath,
            keyOperationClosure: { factoryClosure in
                let operation = MapKeyEncodingOperation(
                    path: codingPath,
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
            runtimeService: runtimeProvider,
            engine: connection,
            trigger: trigger,
            operationManager: operationManager
        )

        let dataProvider = DataProvider(
            source: AnyDataProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        saveProvider(dataProvider, for: localKey)

        return AnyDataProvider(dataProvider)
    }
}
