import Foundation

@dynamicMemberLookup
public enum JSON {
    case unsignedIntValue(UInt64)
    case signedIntValue(Int64)
    case stringValue(String)
    case arrayValue([JSON])
    case dictionaryValue([String: JSON])
    case boolValue(Bool)
    case doubleValue(Double)
    case null

    public var doubleValue: Double? {
        if case let .doubleValue(double) = self {
            return double
        }
        return nil
    }

    public var stringValue: String? {
        if case let .stringValue(str) = self {
            return str
        }
        return nil
    }

    public var arrayValue: [JSON]? {
        if case let .arrayValue(value) = self {
            return value
        }

        return nil
    }

    public var dictValue: [String: JSON]? {
        if case let .dictionaryValue(value) = self {
            return value
        }

        return nil
    }

    public var unsignedIntValue: UInt64? {
        if case let .unsignedIntValue(value) = self {
            return value
        }

        return nil
    }

    public var signedIntValue: Int64? {
        if case let .signedIntValue(value) = self {
            return value
        }

        return nil
    }

    public var boolValue: Bool? {
        if case let .boolValue(value) = self {
            return value
        }

        return nil
    }

    public var isNull: Bool {
        if case .null = self {
            return true
        } else {
            return false
        }
    }

    public subscript(index: Int) -> JSON? {
        if let arr = arrayValue {
            return index < arr.count ? arr[index] : nil
        }
        return nil
    }

    public subscript(key: String) -> JSON? {
        if let dict = dictValue {
            return dict[key]
        }
        return nil
    }

    public subscript(dynamicMember member: String) -> JSON? {
        if let dict = dictValue {
            return dict[member]
        }
        return nil
    }
}

public enum JSONError: Error {
    case unsupported
}

extension JSON: Codable {
    public init(from decoder: Decoder) throws {
        if let unsignedIntValue = try? UInt64(from: decoder) {
            self = .unsignedIntValue(unsignedIntValue)
        } else if let signedIntValue = try? Int64(from: decoder) {
            self = .signedIntValue(signedIntValue)
        } else if let boolValue = try? Bool(from: decoder) {
            self = .boolValue(boolValue)
        } else if let stringValue = try? String(from: decoder) {
            self = .stringValue(stringValue)
        } else if let node = try? [String: JSON](from: decoder) {
            self = .dictionaryValue(node)
        } else if let list = try? [JSON](from: decoder) {
            self = .arrayValue(list)
        } else if let double = try? Double(from: decoder) {
            self = .doubleValue(double)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .unsignedIntValue(value):
            try value.encode(to: encoder)
        case let .signedIntValue(value):
            try value.encode(to: encoder)
        case let .boolValue(value):
            try value.encode(to: encoder)
        case let .stringValue(value):
            try value.encode(to: encoder)
        case let .dictionaryValue(value):
            try value.encode(to: encoder)
        case let .arrayValue(value):
            try value.encode(to: encoder)
        case let .doubleValue(value):
            try value.encode(to: encoder)
        case .null:
            try (JSON?).none.encode(to: encoder)
        }
    }
}

extension JSON: Equatable {}
