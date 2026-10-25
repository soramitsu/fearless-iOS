import Foundation
import UIKit

// sourcery: AutoMockable
public protocol QRService: AnyObject {
    func extractQrCode(from image: UIImage) throws -> QRMatcherType
    func generate(with qrType: QRType, qrSize: CGSize) async throws -> UIImage
}

public final class QRServiceDefault: QRService {
    // MARK: - Private properties

    private let encoder: QREncoder
    private let decoder: QRDecoder
    private let matchers: [QRMatcher]

    // MARK: - Public constructor

    public init(
        encoder: QREncoder? = nil,
        decoder: QRDecoder? = nil,
        matchers: [QRMatcher]? = nil
    ) {
        self.encoder = encoder ?? QREncoderDefault()
        self.decoder = decoder ?? QRDecoderDefault()
        self.matchers = matchers ?? [
            QRInfoMatcher(decoder: self.decoder),
            QRUriMatcherImpl(scheme: "ws"),
        ]
    }

    // MARK: - QRService

    public func extractQrCode(from image: UIImage) throws -> QRMatcherType {
        let code = try proccess(image: image)
        let qrMatcherTypes = matchers.map { $0.match(code: code) }.compactMap { $0 }
        if qrMatcherTypes.isEmpty {
            throw QRExtractionError.invalidImage
        }
        guard qrMatcherTypes.count == 1, let qrType = qrMatcherTypes.first else {
            throw QRExtractionError.severalCoincidences
        }
        return qrType
    }

    public func generate(with qrType: QRType, qrSize: CGSize) async throws -> UIImage {
        let payload = try encoder.encode(with: qrType)
        return try createQR(for: payload, qrSize: qrSize)
    }

    // MARK: - Private methods

    private func createQR(for payload: Data, qrSize: CGSize) throws -> UIImage {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw QRCreationOperationError.generatorUnavailable
        }

        filter.setValue(payload, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")

        guard let qrImage = filter.outputImage else {
            throw QRCreationOperationError.generatedImageInvalid
        }

        let transformedImage: CIImage

        if qrImage.extent.size.width * qrImage.extent.height > 0.0 {
            let transform = CGAffineTransform(
                scaleX: qrSize.width / qrImage.extent.width,
                y: qrSize.height / qrImage.extent.height
            )
            transformedImage = qrImage.transformed(by: transform)
        } else {
            transformedImage = qrImage
        }

        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            throw QRCreationOperationError.bitmapImageCreationFailed
        }

        return UIImage(cgImage: cgImage)
    }

    private func proccess(image: UIImage) throws -> String {
        var optionalImage: CIImage?

        if let ciImage = CIImage(image: image) {
            optionalImage = ciImage
        } else if let cgImage = image.cgImage {
            optionalImage = CIImage(cgImage: cgImage)
        }

        guard let ciImage = optionalImage else {
            throw QRExtractionError.invalidImage
        }

        let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        guard let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: options
        ) else {
            throw QRExtractionError.detectorUnavailable
        }

        let features = detector.features(in: ciImage)

        let receivedString = features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first

        guard let receivedString = receivedString else {
            throw QRExtractionError.noFeatures
        }

        return receivedString
    }
}
