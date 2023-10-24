import Foundation

final class QRUriMatcherImpl: QRMatcherProtocol {
    private let scheme: String

    init(scheme: String) {
        self.scheme = scheme
    }

    func match(code: String) -> QRMatcherType? {
        guard let url = URL(string: code), url.scheme == scheme else {
            return nil
        }

        return .uri(code)
    }
}
