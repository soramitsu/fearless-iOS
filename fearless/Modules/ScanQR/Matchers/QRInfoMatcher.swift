import SSFUtils

final class QRInfoMatcher: QRMatcherProtocol {
    private let decoder: QRDecoderProtocol

    init(decoder: QRDecoderProtocol) {
        self.decoder = decoder
    }

    func match(code: String) -> QRMatcherType? {
        guard let data = code.data(using: .utf8), let info = try? decoder.decode(data: data) else {
            return nil
        }

        return .qrInfo(info)
    }
}
