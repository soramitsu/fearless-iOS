import Foundation

public class OneOfTypeResolver: TypeResolving {
    public let children: [TypeResolving]

    public init(children: [TypeResolving]) {
        self.children = children
    }

    public func resolve(typeName: String, using availableNames: Set<String>) -> String? {
        for child in children {
            if let resolvedTypeName = child.resolve(typeName: typeName, using: availableNames) {
                return resolvedTypeName
            }
        }

        return nil
    }
}
