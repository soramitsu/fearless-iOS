import BigInt
import Foundation

public class DynamicScaleDecoder {
    private var decoder: ScaleDecoder
    public let registry: TypeRegistryCatalogProtocol
    public let version: UInt64

    private var modifiers: [ScaleCodingModifier] = []

    public init(data: Data, registry: TypeRegistryCatalogProtocol, version: UInt64) throws {
        decoder = try ScaleDecoder(data: data)
        self.registry = registry
        self.version = version
    }

    private func handleCommonOption() throws -> Bool {
        let mode = try decoder.readAndConfirm(count: 1)[0]

        switch mode {
        case 0:
            return true
        case 1:
            return false
        default:
            throw DynamicScaleDecoderError.unexpectedOption(byte: mode)
        }
    }

    private func handleBoolOption() throws -> JSON {
        let value = try ScaleBoolOption(scaleDecoder: decoder)

        switch value {
        case .none:
            return .null
        case .valueTrue:
            return .boolValue(true)
        case .valueFalse:
            return .boolValue(false)
        }
    }

    // MARK: - Signed

    func decodeCompactOrFixedInt(length: Int) throws -> JSON {
        if modifiers.last == .compact {
            modifiers.removeLast()
            assertionFailure()
            throw DynamicScaleCoderError.notImplemented
        } else {
            return try decodeFixedInt(length: length)
        }
    }

    private func decodeFixedInt(length: Int) throws -> JSON {
        let data = try decoder.readAndConfirm(count: length)
        let bits = BigUInt(Data(data.reversed()))

        // Two's complement: a set top bit means bits - 2^(8 * length).
        let bitWidth = length * 8
        let value = bits.bitWidth == bitWidth && bitWidth > 0
            ? BigInt(bits) - (BigInt(1) << bitWidth)
            : BigInt(bits)

        return .stringValue(String(value))
    }

    // MARK: - Unsigned

    func decodeCompactOrFixedUInt(length: Int) throws -> JSON {
        if modifiers.last == .compact {
            modifiers.removeLast()
            return try decodeCompact()
        } else {
            return try decodeFixedUInt(length: length)
        }
    }

    private func decodeCompact() throws -> JSON {
        let compact = try BigUInt(scaleDecoder: decoder)
        return .stringValue(String(compact))
    }

    private func decodeFixedUInt(length: Int) throws -> JSON {
        let data = try decoder.readAndConfirm(count: length)
        let value = BigUInt(Data(data.reversed()))
        return .stringValue(String(value))
    }
}

extension DynamicScaleDecoder: DynamicScaleDecoding {
    public var remained: Int { decoder.remained }

    public func read(type: String) throws -> JSON {
        guard let node = registry.node(for: type, version: version) else {
            throw DynamicScaleCoderError.unresolvedType(name: type)
        }

        return try node.accept(decoder: self)
    }

    public func readOption(type: String) throws -> JSON {
        guard let node = registry.node(for: type, version: version) else {
            throw DynamicScaleCoderError.unresolvedType(name: type)
        }

        if node is BoolNode {
            return try handleBoolOption()
        } else if try handleCommonOption() {
            return .null
        } else {
            return try node.accept(decoder: self)
        }
    }

    public func readVector(type: String) throws -> JSON {
        guard let node = registry.node(for: type, version: version) else {
            throw DynamicScaleCoderError.unresolvedType(name: type)
        }

        let length = try BigUInt(scaleDecoder: decoder)

        let jsons = try (0 ..< length).map { _ in try node.accept(decoder: self) }

        return .arrayValue(jsons)
    }

    public func readCompact(type: String) throws -> JSON {
        guard let node = registry.node(for: type, version: version) else {
            throw DynamicScaleCoderError.unresolvedType(name: type)
        }

        modifiers.append(.compact)

        return try node.accept(decoder: self)
    }

    public func readFixedArray(type: String, length: UInt64) throws -> JSON {
        guard let node = registry.node(for: type, version: version) else {
            throw DynamicScaleCoderError.unresolvedType(name: type)
        }

        let jsons = try (0 ..< length).map { _ in try node.accept(decoder: self) }

        return .arrayValue(jsons)
    }

    public func readBytes(length: Int) throws -> JSON {
        let hex = try decoder.readAndConfirm(count: length).toHex(includePrefix: true)

        return .stringValue(hex)
    }

    public func readString() throws -> JSON {
        let string = try String(scaleDecoder: decoder)
        return .stringValue(string)
    }

    public func readU8() throws -> JSON {
        try decodeCompactOrFixedUInt(length: 1)
    }

    public func readU16() throws -> JSON {
        try decodeCompactOrFixedUInt(length: 2)
    }

    public func readU32() throws -> JSON {
        try decodeCompactOrFixedUInt(length: 4)
    }

    public func readU64() throws -> JSON {
        try decodeCompactOrFixedUInt(length: 8)
    }

    public func readU128() throws -> JSON {
        try decodeCompactOrFixedUInt(length: 16)
    }

    public func readU256() throws -> JSON {
        try decodeCompactOrFixedUInt(length: 32)
    }

    public func readI8() throws -> JSON {
        try decodeCompactOrFixedInt(length: 1)
    }

    public func readI16() throws -> JSON {
        try decodeCompactOrFixedInt(length: 2)
    }

    public func readI32() throws -> JSON {
        try decodeCompactOrFixedInt(length: 4)
    }

    public func readI64() throws -> JSON {
        try decodeCompactOrFixedInt(length: 8)
    }

    public func readI128() throws -> JSON {
        try decodeCompactOrFixedInt(length: 16)
    }

    public func readI256() throws -> JSON {
        try decodeCompactOrFixedInt(length: 32)
    }

    public func readBool() throws -> JSON {
        let value = try Bool(scaleDecoder: decoder)
        return .boolValue(value)
    }

    public func read<T: ScaleCodable>() throws -> T {
        try T(scaleDecoder: decoder)
    }
}
