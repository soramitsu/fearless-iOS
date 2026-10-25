import Foundation

public extension Data {
    static func random(of size: Int) -> Data? {
        var bytes = [UInt8](repeating: 0, count: size)
        let status = SecRandomCopyBytes(kSecRandomDefault, size, &bytes)

        if status == errSecSuccess {
            return Data(bytes)
        } else {
            return nil
        }
    }
}
