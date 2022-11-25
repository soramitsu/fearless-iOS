import Foundation

protocol QROperationFactoryProtocol: AnyObject {
    func createCreationOperation(for payload: Data, qrSize: CGSize) -> QRCreationOperation
}

final class QROperationFactory: QROperationFactoryProtocol {
    public init() {}
    public func createCreationOperation(for payload: Data, qrSize: CGSize) -> QRCreationOperation {
        QRCreationOperation(payload: payload, qrSize: qrSize)
    }
}
