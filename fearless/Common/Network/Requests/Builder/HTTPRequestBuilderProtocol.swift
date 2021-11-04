import Foundation

protocol HTTPRequestBuilderProtocol {
    func buildRequest(with _: HTTPRequestConfig) throws -> URLRequest
}
