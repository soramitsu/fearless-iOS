import BigInt
import Foundation

public class RuntimeSchemaResolver: TypeResolving {
    private let schemaResolver: Schema.Resolver

    public init(schemaResolver: Schema.Resolver) {
        self.schemaResolver = schemaResolver
    }

    public func resolve(typeName: String, using _: Set<String>) -> String? {
        if let id = BigUInt(typeName) {
            return try? schemaResolver.typeName(for: id)
        }

        if let _ = try? schemaResolver.resolveType(name: typeName) {
            return typeName
        }

        return nil
    }
}
