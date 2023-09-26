import Foundation

protocol RequestConfigurator {
    func buildRequest(with config: RequestConfig) throws -> URLRequest
}
