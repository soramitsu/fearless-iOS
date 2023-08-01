import Foundation

enum RequestSignerError: Error {
    case badURL
}

protocol RequestSigner {
    func sign(request: inout URLRequest, config: RequestConfig) throws
}
