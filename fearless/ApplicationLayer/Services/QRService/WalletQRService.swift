import UIKit
import SSFQRService
import SSFUtils

/// Keeps the installed QR formats while handling optional Request amounts and
/// separator characters in the wallet name in the app's Sora payload.
final class WalletQRService: QRService {
    private let standard: QRService
    private let soraMatcher = WalletSoraQRMatcher()
    private lazy var soraService = QRServiceDefault(matchers: [soraMatcher])

    init(standard: QRService = QRServiceDefault()) {
        self.standard = standard
    }

    func generate(with qrType: QRType, qrSize: CGSize) async throws -> UIImage {
        var type = qrType
        if case let .addressInfo(info) = qrType, info.amount == nil {
            // The sixth field is optional semantically, but must remain present
            // on the wire so a wallet name containing ':' is unambiguous.
            type = .addressInfo(SoraQRInfo(
                prefix: info.prefix, address: info.address, rawPublicKey: info.rawPublicKey,
                username: info.username, assetId: info.assetId, amount: ""
            ))
        }
        return try await standard.generate(with: type, qrSize: qrSize)
    }

    func extractQrCode(from image: UIImage) throws -> QRMatcherType {
        if let result = try? soraService.extractQrCode(from: image) { return result }
        return try standard.extractQrCode(from: image)
    }

    func extractQrCode(from code: String) throws -> QRMatcherType {
        if let result = soraMatcher.match(code: code) { return result }
        if let url = URL(string: code), url.scheme == "ws" { return .walletConnect(code) }
        // The dependency exposes its other decoders through image extraction
        // only. Re-encode locally to retain the same address/Bokolo formats in
        // camera and gallery paths, without reimplementing private decoders.
        guard let data = code.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw QRDecoderError.brokenFormat
        }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { throw QRDecoderError.brokenFormat }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        guard let bitmap = CIContext().createCGImage(scaled, from: scaled.extent) else {
            throw QRDecoderError.brokenFormat
        }
        return try standard.extractQrCode(from: UIImage(cgImage: bitmap))
    }
}

private final class WalletSoraQRMatcher: QRMatcher {
    func match(code: String) -> QRMatcherType? {
        let fields = code.components(separatedBy: SubstrateQRConstants.fieldsSeparator)
        guard fields.count >= 5, fields[0] == SubstrateQRConstants.prefix,
              !fields[1].isEmpty, let publicKey = try? Data(hexStringSSF: fields[2]),
              !publicKey.isEmpty else { return nil }
        let assetIndex: Int
        let amount: String?
        if fields.count == 5 {
            // Previously generated Receive images omitted the final field.
            assetIndex = 4
            amount = nil
        } else {
            guard let last = fields.last,
                  last.isEmpty || (last.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil &&
                      Decimal(string: last, locale: Locale(identifier: "en_US_POSIX")) != nil) else { return nil }
            assetIndex = fields.count - 2
            amount = last.isEmpty ? nil : last
        }
        let name = fields[3 ..< assetIndex].joined(separator: SubstrateQRConstants.fieldsSeparator)
        return .qrInfo(.sora(SoraQRInfo(
            prefix: fields[0], address: fields[1], rawPublicKey: publicKey,
            username: name, assetId: fields[assetIndex], amount: amount
        )))
    }
}
