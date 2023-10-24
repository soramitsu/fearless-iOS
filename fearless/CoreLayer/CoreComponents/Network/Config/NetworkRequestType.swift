import Foundation

enum NetworkRequestType {
    case plain
    case multipart
    case custom(configurator: RequestConfigurator)
}
