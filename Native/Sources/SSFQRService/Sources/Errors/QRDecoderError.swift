import Foundation

public enum QRDecoderError: Error, Equatable {
    case brokenFormat
    case unexpectedNumberOfFields
    case undefinedPrefix
    case accountIdMismatch
    case wrongDecoder
    case manyCoincidence
}
