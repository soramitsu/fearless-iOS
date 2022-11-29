import Foundation

protocol QROperationFactoryProtocol: AnyObject {
    func createCreationOperation(for payload: Data, qrSize: CGSize) -> QRCreationOperation
}

final class QROperationFactory: QROperationFactoryProtocol {
    init() {}
    func createCreationOperation(for payload: Data, qrSize: CGSize) -> QRCreationOperation {
        QRCreationOperation(payload: payload, qrSize: qrSize)
    }
}
