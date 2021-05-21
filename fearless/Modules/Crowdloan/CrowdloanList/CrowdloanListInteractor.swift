import UIKit
import FearlessUtils
import RobinHood

final class CrowdloanListInteractor {
    weak var presenter: CrowdloanListInteractorOutputProtocol!

    let runtimeService: RuntimeCodingServiceProtocol
    let requestOperationFactory: StorageRequestFactoryProtocol
    let connection: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        requestOperationFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.runtimeService = runtimeService
        self.requestOperationFactory = requestOperationFactory
        self.connection = connection
        self.operationManager = operationManager
        self.logger = logger
    }

    private func provideCrowdloans() {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let codingKeyFactory = StorageKeyFactory()

        let mapper = StorageKeySuffixMapper<StringScaleMapper<UInt32>>(
            type: "ParaId",
            suffixLength: 4,
            coderFactoryClosure: { try coderFactoryOperation.extractNoCancellableResultData() }
        )

        let paraIdsOperation = StorageKeysQueryService(
            connection: connection,
            operationManager: operationManager,
            prefixKeyClosure: { try codingKeyFactory.key(from: .crowdloanFunds) },
            mapper: AnyMapper(mapper: mapper)
        ).longrunOperation()

        let fundsOperation: CompoundOperationWrapper<[StorageResponse<JSON>]> =
            requestOperationFactory.queryItems(
                engine: connection,
                keyParams: {
                    try paraIdsOperation.extractNoCancellableResultData()
                },
                factory: {
                    try coderFactoryOperation.extractNoCancellableResultData()
                }, storagePath: .crowdloanFunds
            )

        fundsOperation.allOperations.forEach { $0.addDependency(paraIdsOperation) }

        fundsOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let crowdloans = try fundsOperation.targetOperation.extractNoCancellableResultData()
                    self?.logger?.info("Crowdloans: \(crowdloans)")
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }
        }

        let operations = [coderFactoryOperation, paraIdsOperation] + fundsOperation.allOperations

        operationManager.enqueue(operations: operations, in: .transient)
    }
}

extension CrowdloanListInteractor: CrowdloanListInteractorInputProtocol {
    func setup() {
        provideCrowdloans()
    }

    func refresh() {
        provideCrowdloans()
    }
}
