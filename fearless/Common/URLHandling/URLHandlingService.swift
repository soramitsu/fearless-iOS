import Foundation

protocol URLHandlingServiceProtocol: AnyObject {
    func handle(url: URL) -> Bool
}

protocol URLHandlingRegistryProtocol: URLHandlingServiceProtocol {
    func setup(children: [URLHandlingServiceProtocol])
    func findService<T>() -> T?
}

enum URLHandlingDependencies {
    static var registry: URLHandlingRegistryProtocol {
        URLHandlingService.shared
    }

    static func keystoreImportService() -> KeystoreImportServiceProtocol? {
        registry.findService()
    }
}

final class URLHandlingService: URLHandlingRegistryProtocol {
    static let shared = URLHandlingService()

    private let queue = DispatchQueue(label: "io.fearless.urlhandling", attributes: .concurrent)
    private var handlers: [URLHandlingServiceProtocol] = []

    func setup(children: [URLHandlingServiceProtocol]) {
        queue.async(flags: .barrier) {
            self.handlers = children
        }
    }

    func findService<T>() -> T? {
        queue.sync {
            handlers.first(where: { $0 is T }) as? T
        }
    }

    private func snapshotHandlers() -> [URLHandlingServiceProtocol] {
        queue.sync { handlers }
    }

    func handle(url: URL) -> Bool {
        // Work on a stable snapshot to avoid races during iteration
        for child in snapshotHandlers() {
            if child.handle(url: url) {
                return true
            }
        }
        return false
    }
}
