import Foundation

public protocol TypeResolving {
    func resolve(typeName: String, using availableNames: Set<String>) -> String?
}
