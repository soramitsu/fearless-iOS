import Foundation

enum NetworkClientType {
    case plain
    case custom(client: NetworkClient)
}
