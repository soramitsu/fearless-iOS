import Foundation

public protocol EthereumChain where Self: RawRepresentable, RawValue == String {
    var alchemyChainIdentifier: String? { get }
    func apiKey(for chainId: String, apiKeyName: String) -> String?
}
