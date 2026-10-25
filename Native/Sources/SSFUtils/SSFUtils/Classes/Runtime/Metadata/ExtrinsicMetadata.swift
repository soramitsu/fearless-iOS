import BigInt
import Foundation

// MARK: - Protocol

public protocol RuntimeExtrinsicMetadata {
    var version: UInt8 { get }
    var type: BigUInt? { get }
    func signedExtensions(using schemaResolver: Schema.Resolver) throws -> [String]
}

// MARK: - V1

public extension RuntimeMetadataV1 {
    struct ExtrinsicMetadata: RuntimeExtrinsicMetadata {
        public let version: UInt8
        public let type: BigUInt? = nil
        public let signedExtensions: [String]

        public init(version: UInt8, signedExtensions: [String]) {
            self.version = version
            self.signedExtensions = signedExtensions
        }

        public func signedExtensions(using _: Schema.Resolver) throws -> [String] {
            signedExtensions
        }
    }
}

extension RuntimeMetadataV1.ExtrinsicMetadata: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try version.encode(scaleEncoder: scaleEncoder)
        try signedExtensions.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        version = try UInt8(scaleDecoder: scaleDecoder)
        signedExtensions = try [String](scaleDecoder: scaleDecoder)
    }
}

// MARK: - V14

public extension RuntimeMetadataV14 {
    struct ExtrinsicMetadata: RuntimeExtrinsicMetadata {
        private let _type: BigUInt
        public var type: BigUInt? { _type }
        public let version: UInt8
        public let signedExtensions: [SignedExtension]

        public init(type: BigUInt, version: UInt8, signedExtensions: [SignedExtension]) {
            _type = type
            self.version = version
            self.signedExtensions = signedExtensions
        }

        public func signedExtensions(using schemaResolver: Schema.Resolver) throws -> [String] {
            try signedExtensions.map {
                try schemaResolver.typeName(for: $0.type)
            }
        }
    }
}

extension RuntimeMetadataV14.ExtrinsicMetadata: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try _type.encode(scaleEncoder: scaleEncoder)
        try version.encode(scaleEncoder: scaleEncoder)
        try signedExtensions.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        _type = try BigUInt(scaleDecoder: scaleDecoder)
        version = try UInt8(scaleDecoder: scaleDecoder)
        signedExtensions = try [SignedExtension](scaleDecoder: scaleDecoder)
    }
}

public extension RuntimeMetadataV14.ExtrinsicMetadata {
    struct SignedExtension {
        public let identifier: String
        public let type: BigUInt
        public let additionalSigned: BigUInt

        public init(identifier: String, type: BigUInt, additionalSigned: BigUInt) {
            self.identifier = identifier
            self.type = type
            self.additionalSigned = additionalSigned
        }
    }
}

extension RuntimeMetadataV14.ExtrinsicMetadata.SignedExtension: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try identifier.encode(scaleEncoder: scaleEncoder)
        try type.encode(scaleEncoder: scaleEncoder)
        try additionalSigned.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        identifier = try String(scaleDecoder: scaleDecoder)
        type = try BigUInt(scaleDecoder: scaleDecoder)
        additionalSigned = try BigUInt(scaleDecoder: scaleDecoder)
    }
}
