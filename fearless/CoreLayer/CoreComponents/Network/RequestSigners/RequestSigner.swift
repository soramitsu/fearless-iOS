import Foundation

protocol RequestSigner {
    func sign(request: inout URLRequest, config: RequestConfig)
}
