import Foundation
import FireMock

protocol NetworkMockManagerProtocol {
    var isEnabled: Bool { get }

    func enable()
    func disable()
}

class NetworkMockManager {
    static let shared = NetworkMockManager()

    private lazy var initializeMockSupport: () -> Void = {
        URLSessionConfiguration.classInit
        return {}
    }()

    private init() {}
}

extension NetworkMockManager: NetworkMockManagerProtocol {
    var isEnabled: Bool {
        return FireMock.isEnabled
    }

    public func enable() {
        initializeMockSupport()

        FireMock.unregisterAll()
        FireMock.enabled(true)
    }

    public func disable() {
        FireMock.unregisterAll()
        FireMock.enabled(false)
    }
}
