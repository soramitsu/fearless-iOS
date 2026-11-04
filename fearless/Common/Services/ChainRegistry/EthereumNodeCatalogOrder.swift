import Foundation
import SSFModels

protocol EthereumNodeCatalogOrderProtocol: AnyObject {
    /// The network's node URLs in the order the chain catalog lists them; empty before the first download.
    func nodeOrder(for chainId: ChainModel.Id) -> [URL]
    /// Keeps the node order of every EVM network in a downloaded chain catalog.
    func record(catalog data: Data)
}

/// The order the chain catalog lists each EVM network's nodes in. `ChainModel.nodes` is a set and Core Data keeps no
/// order either, so the order is kept here when the catalog is downloaded, and automatic node selection follows it.
final class EthereumNodeCatalogOrder: EthereumNodeCatalogOrderProtocol {
    static let shared = EthereumNodeCatalogOrder(defaults: .standard)

    private static let storageKey = "jp.co.soramitsu.fearless.ethereum.catalogNodeOrder.v1"

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var order: [ChainModel.Id: [String]]?

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func nodeOrder(for chainId: ChainModel.Id) -> [URL] {
        lock.lock()
        defer { lock.unlock() }

        return (loadedOrder()[chainId] ?? []).compactMap(URL.init(string:))
    }

    func record(catalog data: Data) {
        guard let recorded = Self.nodeOrder(inCatalog: data), !recorded.isEmpty else {
            return
        }

        lock.lock()
        defer { lock.unlock() }

        guard recorded != loadedOrder() else {
            return
        }
        order = recorded
        defaults.set(recorded, forKey: Self.storageKey)
    }

    /// The node URLs of every EVM network (`"ethereum"` among its options) in a chain catalog, in catalog order.
    static func nodeOrder(inCatalog data: Data) -> [ChainModel.Id: [String]]? {
        guard let chains = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return nil
        }

        return chains.reduce(into: [ChainModel.Id: [String]]()) { result, chain in
            guard
                let chainId = chain["chainId"] as? String,
                let options = chain["options"] as? [String],
                options.contains(ChainOptions.ethereum.rawValue),
                let nodes = chain["nodes"] as? [[String: Any]]
            else {
                return
            }

            result[chainId] = nodes.compactMap { $0["url"] as? String }
        }
    }

    private func loadedOrder() -> [ChainModel.Id: [String]] {
        if let order {
            return order
        }
        let stored = defaults.dictionary(forKey: Self.storageKey) as? [ChainModel.Id: [String]] ?? [:]
        order = stored
        return stored
    }
}
