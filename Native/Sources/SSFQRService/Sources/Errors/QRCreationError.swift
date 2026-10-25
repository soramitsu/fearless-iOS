import Foundation

public enum QRCreationOperationError: Error {
    case generatorUnavailable
    case generatedImageInvalid
    case bitmapImageCreationFailed
}
