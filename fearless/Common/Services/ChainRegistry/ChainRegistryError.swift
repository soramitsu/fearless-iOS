import Foundation

enum ChainRegistryError: Error {
    case connectionUnavailable
    case runtimeMetadaUnavailable
    case chainUnavailable(chainId: String)
}
