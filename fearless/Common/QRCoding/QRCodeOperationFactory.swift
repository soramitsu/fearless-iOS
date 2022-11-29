import Foundation

protocol QRCodeOperationFactoryProtocol: AnyObject {
    func createQRCreationOperation(for payload: Data, qrSize: CGSize) -> QRCreationOperation
}

final class QRCodeOperationFactory: QRCodeOperationFactoryProtocol {
    func createQRCreationOperation(for payload: Data, qrSize: CGSize) -> QRCreationOperation {
        QRCreationOperation(payload: payload, qrSize: qrSize)
    }
}
