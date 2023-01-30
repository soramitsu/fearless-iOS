import FearlessUtils

protocol QRScanMatcherProtocol: QRMatcherProtocol {
    var qrInfo: QRInfo? { get }
}

final class QRScanMatcher: QRScanMatcherProtocol {
    private(set) var qrInfo: QRInfo?

    private let decoder: QRDecoderProtocol

    init(decoder: QRDecoderProtocol) {
        self.decoder = decoder
    }

    func match(code: String) -> Bool {
        guard let data = code.data(using: .utf8), let info = try? decoder.decode(data: data) else {
            return false
        }

        qrInfo = info

        return true
    }
}
