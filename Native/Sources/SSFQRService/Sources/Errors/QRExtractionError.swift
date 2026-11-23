import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum QRExtractionError: Error {
    case invalidImage
    case detectorUnavailable
    case noFeatures
    case invalidQrCode
    case severalCoincidences
}
