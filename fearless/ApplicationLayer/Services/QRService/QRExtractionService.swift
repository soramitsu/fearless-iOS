import Foundation
import UIKit

protocol QRExtractionServiceProtocol {
    func extract(
        from image: UIImage,
        using matcher: QRMatcherProtocol,
        dispatchCompletionIn queue: DispatchQueue?,
        completionBlock: @escaping (Result<String, Error>) -> Void
    )
}

enum QRExtractionServiceError: Error {
    case invalidImage
    case detectorUnavailable
    case noFeatures
}

final class QRExtractionService {
    private let processingQueue: DispatchQueue

    init(processingQueue: DispatchQueue) {
        self.processingQueue = processingQueue
    }

    private func proccess(image: UIImage, with matcher: QRMatcherProtocol) -> Result<String, Error> {
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

        let optionalMatch: String? = features
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            .first { matcher.match(code: $0) }

        guard let match = optionalMatch else {
            return .failure(QRExtractionServiceError.noFeatures)
        }

        return .success(match)
    }
}

extension QRExtractionService: QRExtractionServiceProtocol {
    func extract(
        from image: UIImage,
        using matcher: QRMatcherProtocol,
        dispatchCompletionIn queue: DispatchQueue?,
        completionBlock: @escaping (Result<String, Error>) -> Void
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
