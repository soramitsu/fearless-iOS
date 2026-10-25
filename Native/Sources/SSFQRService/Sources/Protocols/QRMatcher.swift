import Foundation

public protocol QRMatcher {
    func match(code: String) -> QRMatcherType?
}
