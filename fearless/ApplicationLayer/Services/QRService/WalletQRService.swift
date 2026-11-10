import UIKit
import SSFQRService
import SSFUtils

/// Keeps the installed QR formats while handling optional Request amounts and
/// separator characters in the wallet name in the app's Sora payload.
///
/// WalletConnect pairing codes use the `wc:` scheme (EIP-1328). The shared decoder's
/// default matchers report `ws:` URLs as WalletConnect instead, so its WalletConnect
/// results are refused here and `wc:` codes are matched by `WalletConnectQRMatcher`.
final class WalletQRService: QRService {
    private let standard: QRService
    private let soraMatcher = WalletSoraQRMatcher()
    private let walletConnectMatcher = WalletConnectQRMatcher()
    private lazy var soraService = QRServiceDefault(matchers: [soraMatcher])
    private lazy var walletConnectService = QRServiceDefault(matchers: [walletConnectMatcher])

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
        if let result = try? walletConnectService.extractQrCode(from: image) { return result }
        return try Self.refusingSocketAddresses(standard.extractQrCode(from: image))
    }

    func extractQrCode(from code: String) throws -> QRMatcherType {
        if let result = soraMatcher.match(code: code) { return result }
        if let result = walletConnectMatcher.match(code: code) { return result }
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
        return try Self.refusingSocketAddresses(standard.extractQrCode(from: UIImage(cgImage: bitmap)))
    }

    /// The only WalletConnect result the shared decoder produces is a `ws:` URL, which is
    /// a node address and never a pairing code.
    private static func refusingSocketAddresses(_ result: QRMatcherType) throws -> QRMatcherType {
        guard case .walletConnect = result else {
            return result
        }
        throw QRDecoderError.brokenFormat
    }
}

/// Matches WalletConnect pairing codes. The SDK accepts only the lowercase `wc:` prefix.
final class WalletConnectQRMatcher: QRMatcher {
    func match(code: String) -> QRMatcherType? {
        guard code.hasPrefix("wc:"), URL(string: code) != nil else {
            return nil
        }
        return .walletConnect(code)
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
