import Foundation
import WalletCore

public struct WalletEngineConfiguration: Sendable {
    public var storageDirectory: URL
    public var keychainService: String
    public var urlSession: URLSession
    var directoryURL: URL {
        URL(fileURLWithPath: storageDirectory.path, isDirectory: true).standardized
    }

    public init(storageDirectory: URL, keychainService: String, urlSession: URLSession) {
        self.storageDirectory = storageDirectory
        self.keychainService = keychainService
        self.urlSession = urlSession
    }

    public static var `default`: Self {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        return Self(
            storageDirectory: URL.homeDirectory.appending(path: "Library/Application Support/Fearless"),
            keychainService: "jp.co.soramitsu.fearlesswallet.mac",
            urlSession: URLSession(configuration: config)
        )
    }
}

/// All windows and composition roots pointing at one directory share its vault state and
/// transaction serialization. Keep weak references so closing the last client releases its key.
private final class StoreRegistry: @unchecked Sendable {
    static let shared = StoreRegistry()
    private final class Entry {
        weak var store: EngineStore?
        init(_ store: EngineStore) {
            self.store = store
        }
    }

    private let lock = NSLock()
    private var entries: [URL: Entry] = [:]

    func store(for configuration: WalletEngineConfiguration) -> EngineStore {
        lock.withLock {
            let directory = configuration.directoryURL
            if let store = entries[directory]?.store {
                return store
            }
            entries = entries.filter { $0.value.store != nil }
            let store = EngineStore(configuration: configuration)
            entries[directory] = Entry(store)
            return store
        }
    }
}

public enum WalletEngineFactory {
    public static func makeLiveServices(configuration: WalletEngineConfiguration = .default) -> WalletServices {
        let store = StoreRegistry.shared.store(for: configuration)
        let network = NetworkServices(store: store, session: configuration.urlSession)
        return WalletServices(
            vault: store,
            wallets: store,
            catalog: Catalog(),
            nodes: network,
            balances: network,
            prices: network,
            transfers: network,
            activity: network
        )
    }
}
