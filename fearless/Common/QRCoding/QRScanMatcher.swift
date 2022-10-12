import FearlessUtils

protocol QRScanMatcherProtocol: QRMatcherProtocol {
    var addressInfo: AddressQRInfo? { get }
}

final class QRScanMatcher: QRScanMatcherProtocol {
    private(set) var addressInfo: AddressQRInfo?

    private let decoder: NewQRDecoderProtocol

    init(decoder: NewQRDecoderProtocol) {
        self.decoder = decoder
    }

    func match(code: String) -> Bool {
        guard let data = code.data(using: .utf8) else {
            return false
        }

        guard let info = try? decoder.decode(data: data) else {
            return false
        }

        addressInfo = info

        return true
    }
}
