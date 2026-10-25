import Foundation

public class AccountIdAddressNode: Node {
    public var typeName: String { "AccountIdAddress" }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.append(json: value, type: "AccountId")
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.read(type: "AccountId")
    }
}
