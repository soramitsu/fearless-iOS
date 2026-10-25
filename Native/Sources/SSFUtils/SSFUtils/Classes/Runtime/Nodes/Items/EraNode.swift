import Foundation

public class EraNode: Node {
    public var typeName: String { GenericType.era.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        let era = try value.map(to: Era.self)
        try encoder.append(encodable: era)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let era: Era = try decoder.read()

        return try era.toScaleCompatibleJSON()
    }
}
