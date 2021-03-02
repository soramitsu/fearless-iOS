import Foundation

struct ExtrinsicConstants {
    static let extrinsicVersion: UInt8 = 132
    static let signedExtrinsicInitialVersion: UInt8 = 128
    static let accountIdLength: UInt8 = 32
}

struct Call {
    let moduleIndex: UInt8
    let callIndex: UInt8
    let arguments: Data?
}

enum ExtrinsicCodingError: Error {
    case unsupportedSignatureVersion
}
