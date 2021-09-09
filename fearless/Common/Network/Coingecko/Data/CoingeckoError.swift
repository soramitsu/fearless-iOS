import Foundation

enum CoingeckoError: Error {
    case cantBuildURL
    case emptyResult
    case multipleAssetsNotSupported
}
