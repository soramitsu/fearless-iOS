import Foundation

enum RandomDataError: Error {
    case generatorFailed
}

extension Data {
    static func generateRandomBytes(of length: Int) throws -> Data {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw RandomDataError.generatorFailed
        }

        return data
    }
}
