import RobinHood
import UIKit

protocol QROperationFactoryProtocol: AnyObject {
    func createCreationOperation(for payload: Data, qrSize: CGSize) -> QRCreationOperation
}

final class QROperationFactory: QROperationFactoryProtocol {
    func createCreationOperation(for payload: Data, qrSize: CGSize) -> QRCreationOperation {
        QRCreationOperation(payload: payload, qrSize: qrSize)
    }
}

protocol QRServiceProtocol: AnyObject {
    @discardableResult
    func generate(
        with qrType: QRType,
        qrSize: CGSize,
        runIn queue: DispatchQueue,
        completionBlock: @escaping (Result<UIImage, Error>?) -> Void
    ) throws -> Operation
}

final class QRService {
    private let operationFactory: QROperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let encoder: QREncoderProtocol

    init(
        operationFactory: QROperationFactoryProtocol,
        encoder: QREncoderProtocol = QREncoder(),
        operationQueue: OperationQueue = OperationQueue()
    ) {
        self.operationFactory = operationFactory
        self.encoder = encoder
        self.operationQueue = operationQueue
    }
}

extension QRService: QRServiceProtocol {
    @discardableResult
    func generate(
        with qrType: QRType,
        qrSize: CGSize,
        runIn queue: DispatchQueue,
        completionBlock: @escaping (Result<UIImage, Error>?) -> Void
    ) throws -> Operation {
        let payload = try encoder.encode(with: qrType)
        let operation = operationFactory.createCreationOperation(for: payload, qrSize: qrSize)

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        operationQueue.addOperation(operation)
        return operation
    }
}
