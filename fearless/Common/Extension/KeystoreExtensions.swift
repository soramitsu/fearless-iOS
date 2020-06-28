import Foundation
import SoraKeystore

enum KeystoreKey: String, CaseIterable {
    case privateKey
    case pincode
    case seedEntropy
}

extension KeystoreProtocol {
    func deleteAll() throws {
        try deleteKeysIfExist(for: KeystoreKey.allCases.map({ $0.rawValue }))
    }
}
