import Foundation
import UIKit

protocol QRExtractionServiceProtocol {
    func extract(
        from image: UIImage,
        using matcher: QRMatcherProtocol,
        dispatchCompletionIn queue: DispatchQueue?,
        completionBlock: @escaping (Result<String, QRExtractionServiceError>) -> Void
    )
}

enum QRExtractionServiceError: Error {
    case invalidImage
    case detectorUnavailable
    case noFeatures
    case plainAddress(address: String)
}

final class QRExtractionService {
    private let processingQueue: DispatchQueue

    init(processingQueue: DispatchQueue) {
        self.processingQueue = processingQueue
    }

    private func proccess(image: UIImage, with matcher: QRMatcherProtocol) -> Result<String, QRExtractionServiceError> {
        var optionalImage: CIImage?

        if let ciImage = CIImage(image: image) {
            optionalImage = ciImage
        } else if let cgImage = image.cgImage {
            optionalImage = CIImage(cgImage: cgImage)
        }

        guard let ciImage = optionalImage else {
            return .failure(QRExtractionServiceError.invalidImage)
        }

        let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        guard let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: options
        ) else {
            return .failure(QRExtractionServiceError.detectorUnavailable)
        }

        let features = detector.features(in: ciImage)

        let receivedString = features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first

        guard let receivedString = receivedString else {
            return .failure(QRExtractionServiceError.noFeatures)
        }

        guard matcher.match(code: receivedString) else {
            return .failure(QRExtractionServiceError.plainAddress(address: receivedString))
        }

        return .success(receivedString)
    }
}

extension QRExtractionService: QRExtractionServiceProtocol {
    func extract(
        from image: UIImage,
        using matcher: QRMatcherProtocol,
        dispatchCompletionIn queue: DispatchQueue?,
        completionBlock: @escaping (Result<String, QRExtractionServiceError>) -> Void
    ) {
        processingQueue.async {
            let result = self.proccess(image: image, with: matcher)

            if let queue = queue {
                queue.async {
                    completionBlock(result)
                }
            } else {
                completionBlock(result)
            }
        }
    }
}
