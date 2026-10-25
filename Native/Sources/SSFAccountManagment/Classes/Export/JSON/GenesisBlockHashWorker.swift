import Foundation
import RobinHood
import SSFExtrinsicKit
import SSFUtils

// sourcery: AutoMockable
protocol GenesisBlockHashWorkerProtocol {
    func getGenesisHash() async -> String?
}

final class GenesisBlockHashWorker: GenesisBlockHashWorkerProtocol {
    private let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol

    init(
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        operationManager: OperationManagerProtocol = OperationManagerFacade.sharedManager
    ) {
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.operationManager = operationManager
    }

    func getGenesisHash() async -> String? {
        let genesisOperation = extrinsicOperationFactory.createGenesisBlockHashOperation()
        genesisOperation.qualityOfService = .userInitiated
        operationManager.enqueue(operations: [genesisOperation], in: .transient)

        return await withUnsafeContinuation { continuation in
            genesisOperation.completionBlock = {
                let genesisHash = try? genesisOperation.extractResultData()
                continuation.resume(returning: genesisHash)
            }
        }
    }
}
