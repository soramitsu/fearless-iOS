import Foundation

protocol HTTPHeadersBuilderProtocol {
    func buildHeaders() -> [String: String]?
}
