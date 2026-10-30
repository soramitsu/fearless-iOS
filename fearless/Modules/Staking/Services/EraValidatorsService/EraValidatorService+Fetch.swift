import Foundation
import RobinHood
import SSFUtils
import SSFModels
import SSFRuntimeCodingService

private typealias IdentifiableExposure = (Data, ValidatorExposure)

extension EraValidatorService {
    private func handleEraDecodingResult(result: Result<ActiveEraInfo, Error>?, read generation: Int) {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger?.error(ConvenienceError(error: ChainRegistryError.runtimeMetadaUnavailable.localizedDescription).localizedDescription)
            didFail(ChainRegistryError.runtimeMetadaUnavailable, read: generation)
            return
        }
        let isPagedValidatorsRequest = runtimeService.snapshot?.metadata.getStorageMetadata(for: .erasStakersOverview) != nil

        switch result {
        case let .success(era):
            didReceiveActiveEra(era.index)

            if isPagedValidatorsRequest {
                fetchEraStakersPaged(activeEra: era.index, read: generation) { [weak self] eraStakers in
                    self?.didReceiveSnapshot(eraStakers)
                }
            } else {
                fetchEraStakers(activeEra: era.index) { [weak self] eraStakers in
                    self?.didReceiveSnapshot(eraStakers)
                }
            }
        case let .failure(error):
            logger?.error("Did receive era decoding error: \(error)")
            didFail(error, read: generation)
        case .none:
            logger?.warning("Error decoding operation canceled")
            didFail(BaseOperationError.parentOperationCancelled, read: generation)
        }
    }

    func didUpdateActiveEraItem(_ eraItem: ChainStorageItem?) {
        lastActiveEraItem = eraItem
        let generation = beginActiveEraRead()

        guard let runtimeCodingService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger?.error(ConvenienceError(error: ChainRegistryError.runtimeMetadaUnavailable.localizedDescription).localizedDescription)
            didFail(ChainRegistryError.runtimeMetadaUnavailable, read: generation)
            return
        }

        guard let eraItem = eraItem else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<ActiveEraInfo>(
            path: .activeEra,
            data: eraItem.data
        )
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                self?.handleEraDecodingResult(result: decodingOperation.result, read: generation)
            }
        }

        operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }
}
