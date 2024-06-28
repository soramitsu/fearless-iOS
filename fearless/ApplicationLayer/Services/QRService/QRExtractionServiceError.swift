import Foundation

enum QRExtractionServiceError: Error {
    case invalidImage
    case detectorUnavailable
    case noFeatures
    case plainAddress(address: String)
}
