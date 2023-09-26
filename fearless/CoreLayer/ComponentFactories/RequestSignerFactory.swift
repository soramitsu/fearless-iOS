import Foundation

enum RequestSignerFactoryError: Error {
    case signingTypeNotSupported
}

protocol RequestSignerFactory {
    func buildRequestSigner(with type: RequestSigningType) throws -> RequestSigner?
}

final class BaseRequestSignerFactory: RequestSignerFactory {
    func buildRequestSigner(with type: RequestSigningType) throws -> RequestSigner? {
        switch type {
        case .none:
            return nil
        case .bearer:
            throw RequestSignerFactoryError.signingTypeNotSupported
        case let .custom(signer):
            return signer
        }
    }
}
