import Foundation
import IrohaCrypto
import SSFUtils
import TweetNacl

// sourcery: AutoMockable
public protocol EncryptionServiceProtocol {
    func getDecrypted(from message: String?, password: String) throws -> String?
    func createEncryptedData(with password: String, message: String?) throws -> Data?
}

public class EncryptionService: NSObject, EncryptionServiceProtocol {
    public func getDecrypted(from message: String?, password: String) throws -> String? {
        guard let message = message else {
            return nil
        }
        guard let passwordData = password.data(using: .utf8) else {
            throw CloudStorageServiceError.incorectPassword
        }

        let data = try Data(hexStringSSF: message)

        let scryptParameters = try ScryptParameters(data: data)

        let encryptionKey = try IRScryptKeyDeriviation()
            .deriveKey(
                from: passwordData,
                salt: scryptParameters.salt,
                scryptN: UInt(scryptParameters.scryptN),
                scryptP: UInt(scryptParameters.scryptP),
                scryptR: UInt(scryptParameters.scryptR),
                length: UInt(KeystoreConstants.encryptionKeyLength)
            )

        let nonceStart = ScryptParameters.encodedLength
        let nonceEnd = ScryptParameters.encodedLength + KeystoreConstants.nonceLength
        let encnonce = Data(data[nonceStart ..< nonceEnd])
        let encryptedData = Data(data[nonceEnd...])

        let dencodedData = try NaclSecretBox.open(
            box: encryptedData,
            nonce: encnonce,
            key: encryptionKey
        )
        return String(decoding: dencodedData, as: UTF8.self)
    }

    public func createEncryptedData(with password: String, message: String?) throws -> Data? {
        guard let message = message else {
            return nil
        }
        guard let passwordData = password.data(using: .utf8) else {
            throw CloudStorageServiceError.incorectPassword
        }

        let scryptParameters = try ScryptParameters()

        let encryptionKey = try IRScryptKeyDeriviation()
            .deriveKey(
                from: passwordData,
                salt: scryptParameters.salt,
                scryptN: UInt(scryptParameters.scryptN),
                scryptP: UInt(scryptParameters.scryptP),
                scryptR: UInt(scryptParameters.scryptR),
                length: UInt(KeystoreConstants.encryptionKeyLength)
            )

        let messageUtf8 = Data(message.utf8)
        let nonce = try Data.generateRandomBytes(of: KeystoreConstants.nonceLength)
        let encrypted = try NaclSecretBox.secretBox(
            message: messageUtf8,
            nonce: nonce,
            key: encryptionKey
        )
        return scryptParameters.encode() + nonce + encrypted
    }
}
