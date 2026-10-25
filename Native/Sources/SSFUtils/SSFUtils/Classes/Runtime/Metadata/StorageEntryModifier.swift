import Foundation

// MARK: - RuntimeStorageEntryModifier

public enum RuntimeStorageEntryModifier: UInt8 {
    case optional
    case defaultModifier
}

// MARK: - ScaleCodable

extension RuntimeStorageEntryModifier: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try rawValue.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        let rawValue = try UInt8(scaleDecoder: scaleDecoder)

        guard let value = RuntimeStorageEntryModifier(rawValue: rawValue) else {
            throw ScaleCodingError.unexpectedDecodedValue
        }

        self = value
    }
}
