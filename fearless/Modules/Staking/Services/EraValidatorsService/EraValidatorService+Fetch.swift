import Foundation
import RobinHood
import SSFUtils
import SSFModels
import SSFRuntimeCodingService

extension EraValidatorService {
    private func handleEraDecodingResult(result: Result<ActiveEraInfo, Error>?) {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger?.error(ConvenienceError(error: ChainRegistryError.runtimeMetadaUnavailable.localizedDescription).localizedDescription)
            return
        }
        let isPagedValidatorsRequest = runtimeService.snapshot?.metadata.getStorageMetadata(for: .erasStakersOverview) != nil

        switch result {
        case let .success(era):
            didReceiveActiveEra(era.index)

            if isPagedValidatorsRequest {
                fetchEraStakersPaged(activeEra: era.index) { [weak self] eraStakers in
                    self?.didReceiveSnapshot(eraStakers)
                }
            } else {
                fetchEraStakers(activeEra: era.index) { [weak self] eraStakers in
                    self?.didReceiveSnapshot(eraStakers)
                }
            }
        case let .failure(error):
            logger?.error("Did receive era decoding error: \(error)")
        case .none:
            logger?.warning("Error decoding operation canceled")
        }
    }

    func didUpdateActiveEraItem(_ eraItem: ChainStorageItem?) {
        guard let runtimeCodingService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger?.error(ConvenienceError(error: ChainRegistryError.runtimeMetadaUnavailable.localizedDescription).localizedDescription)
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
                self?.handleEraDecodingResult(result: decodingOperation.result)
            }
        }

        operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }
}
