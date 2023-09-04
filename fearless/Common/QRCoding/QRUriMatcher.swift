import Foundation

protocol QRUriMatcher: QRMatcherProtocol {
    var url: URL? { get }
}

final class QRUriMatcherImpl: QRUriMatcher {
    var url: URL?

    let scheme: String

    init(scheme: String) {
        self.scheme = scheme
    }

    func match(code: String) -> Bool {
        guard let url = URL(string: code), url.scheme == scheme else {
            return false
        }

        self.url = url

        return true
    }
}
