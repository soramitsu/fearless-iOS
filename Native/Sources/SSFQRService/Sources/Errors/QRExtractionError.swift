import Foundation
import UIKit

enum QRExtractionError: Error {
    case invalidImage
    case detectorUnavailable
    case noFeatures
    case invalidQrCode
    case severalCoincidences
}
