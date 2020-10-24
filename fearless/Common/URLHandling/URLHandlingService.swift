import Foundation

protocol URLHandlingServiceProtocol: class {
    func handle(url: URL) -> Bool
}

final class URLHandlingService {
    static let shared = URLHandlingService()

    private(set) var children: [URLHandlingServiceProtocol] = []

    func setup(children: [URLHandlingServiceProtocol]) {
        self.children = children
    }

    func findService<T>() -> T? {
        return children.first(where: { $0 is T }) as? T
    }
}

extension URLHandlingService: URLHandlingServiceProtocol {
    func handle(url: URL) -> Bool {
        for child in children {
            if child.handle(url: url) {
                return true
            }
        }

        return false
    }
}
