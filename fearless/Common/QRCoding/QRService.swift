import RobinHood
import Foundation
import CommonWallet

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
    let operationFactory: QRCodeOperationFactoryProtocol
    let operationQueue: OperationQueue

    private let encoder: QREncoderProtocol

    init(
        operationFactory: QRCodeOperationFactoryProtocol,
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
        let operation = operationFactory.createQRCreationOperation(for: payload, qrSize: qrSize)

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        operationQueue.addOperation(operation)
        return operation
    }
}
