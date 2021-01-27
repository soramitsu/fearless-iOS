import Foundation

public struct JSONCodingKey: CodingKey {
    public var stringValue: String

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }

    public var intValue: Int?

    public init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}

@dynamicMemberLookup
enum JSON {
    case intValue(Int)
    case stringValue(String)
    case arrayValue([JSON])
    case dictionaryValue([String: JSON])

    var stringValue: String? {
        if case .stringValue(let str) = self {
            return str
        }
        return nil
    }

    var arrayValue: [JSON]? {
        if case .arrayValue(let value) = self {
            return value
        }

        return nil
    }

    var dictValue: [String: JSON]? {
        if case .dictionaryValue(let value) = self {
            return value
        }

        return nil
    }

    var intValue: Int? {
        if case .intValue(let value) = self {
            return value
        }

        return nil
    }

    subscript(index: Int) -> JSON? {
        if let arr = arrayValue {
            return index < arr.count ? arr[index] : nil
        }
        return nil
    }

    subscript(key: String) -> JSON? {
        if let dict = dictValue {
            return dict[key]
        }
        return nil
    }

    subscript(dynamicMember member: String) -> JSON? {
        if let dict = dictValue {
            return dict[member]
        }
        return nil
    }
}

enum JSONError: Error {
    case unsupported
}

extension JSON: Codable {
    init(from decoder: Decoder) throws {
        if let intValue = try? Int(from: decoder) {
            self = .intValue(intValue)
        } else if let stringValue = try? String(from: decoder) {
            self = .stringValue(stringValue)
        } else if let node = try? [String: JSON](from: decoder) {
            self = .dictionaryValue(node)
        } else if let list = try? [JSON](from: decoder) {
            self = .arrayValue(list)
        } else {
            throw JSONError.unsupported
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .intValue(let value):
            try value.encode(to: encoder)
        case .stringValue(let value):
            try value.encode(to: encoder)
        case .dictionaryValue(let value):
            try value.encode(to: encoder)
        case .arrayValue(let value):
            try value.encode(to: encoder)
        }
    }
}
