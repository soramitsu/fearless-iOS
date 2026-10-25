import Foundation
import SoraKeystore

extension KeystoreProtocol {
    func loadIfKeyExists(_ tag: String) throws -> Data? {
        guard try checkKey(for: tag) else {
            return nil
        }

        return try fetchKey(for: tag)
    }

    func fetchDeriviationForAddress(_ path: String) throws -> String? {
        guard let data = try loadIfKeyExists(path) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
