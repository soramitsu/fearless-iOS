import Foundation

struct PolkaswapJSON: Codable {
    private var uint32: UInt32?
    private var string: String?
    private var bool: Bool?
    private var double: Double?
    private var stringArray: [String]?

    init(_ uint32: UInt32) {
        self.uint32 = uint32
    }

    init(_ string: String) {
        self.string = string
    }

    init(_ bool: Bool) {
        self.bool = bool
    }

    init(_ double: Double) {
        self.double = double
    }

    init(_ stringArray: [String]) {
        self.stringArray = stringArray
    }

    init(from decoder: Decoder) throws {
        if let uint32 = try? decoder.singleValueContainer().decode(UInt32.self) {
            self.uint32 = uint32
            return
        }

        if let string = try? decoder.singleValueContainer().decode(String.self) {
            self.string = string
            return
        }

        if let bool = try? decoder.singleValueContainer().decode(Bool.self) {
            self.bool = bool
            return
        }

        if let double = try? decoder.singleValueContainer().decode(Double.self) {
            self.double = double
        }

        if let stringArray = try? decoder.singleValueContainer().decode([String].self) {
            self.stringArray = stringArray
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let anyValue = value() {
            if let value = anyValue as? UInt32 {
                try container.encode(value)
                return
            }

            if let value = anyValue as? String {
                try container.encode(value)
                return
            }

            if let value = anyValue as? Bool {
                try container.encode(value)
                return
            }

            if let value = anyValue as? Double {
                try container.encode(value)
                return
            }

            if let value = anyValue as? [String] {
                try container.encode(value)
                return
            }
        }

        try container.encodeNil()
    }

    func value() -> Any? {
        uint32 ?? string ?? bool ?? double ?? stringArray
    }
}
