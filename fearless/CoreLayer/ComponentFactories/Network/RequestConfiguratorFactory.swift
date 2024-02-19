import Foundation

enum RequestConfiguratorFactoryError: Error {
    case requestTypeNotSupported
}

protocol RequestConfiguratorFactory {
    func buildRequestConfigurator(with type: NetworkRequestType, baseURL: URL) throws -> RequestConfigurator
}

final class BaseRequestConfiguratorFactory: RequestConfiguratorFactory {
    func buildRequestConfigurator(with type: NetworkRequestType, baseURL: URL) throws -> RequestConfigurator {
        switch type {
        case .plain:
            return RESTRequestConfigurator(baseURL: baseURL)
        case .multipart:
            throw RequestConfiguratorFactoryError.requestTypeNotSupported
        case let .custom(configurator):
            return configurator
        }
    }
}
