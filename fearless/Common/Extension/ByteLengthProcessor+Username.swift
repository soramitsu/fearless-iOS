import Foundation

extension ByteLengthProcessor {
    static var username: ByteLengthProcessor {
        ByteLengthProcessor(maxLength: 32, encoding: .utf8)
    }
}
