import FearlessUtils

protocol QRScanMatcherProtocol: QRMatcherProtocol {
    var addressInfo: AddressQRInfo? { get }
}

final class QRScanMatcher: QRScanMatcherProtocol {
    private(set) var addressInfo: AddressQRInfo?

    private let decoder: QRDecoderProtocol

    init(decoder: QRDecoderProtocol) {
        self.decoder = decoder
    }

    func match(code: String) -> Bool {
        guard let data = code.data(using: .utf8), let info = try? decoder.decode(data: data) else {
            return false
        }

        addressInfo = info

        return true
    }
}
