import Foundation
import IrohaCrypto
import TweetNacl

public class KeystoreExtractor: KeystoreExtracting {
    public init() {}

    public func extractFromDefinition(
        _ info: KeystoreDefinition,
        password: String?
    ) throws -> KeystoreData {
        guard let data = Data(base64Encoded: info.encoded) else {
            throw KeystoreExtractorError.invalidBase64
        }

        let keyDerivationName: String? = info.encoding.type.count > 0 ? info.encoding.type[0] : nil
        let cipherType: String? = info.encoding.type.count > 1 ? info.encoding.type[1] : nil

        let encodedData: Data

        if keyDerivationName == nil, cipherType == nil {
            encodedData = data
        } else if keyDerivationName == KeystoreEncodingType.scrypt.rawValue,
                  cipherType == KeystoreEncodingType.xsalsa.rawValue
        {
            // Check the complete encrypted framing before deriving a key or slicing the nonce.
            // A valid scrypt header alone does not make the following ranges safe to read.
            let minimumLength = ScryptParameters.encodedLength + KeystoreConstants.nonceLength +
                KeystoreConstants.authenticationTagLength
            guard data.count >= minimumLength else {
                throw KeystoreExtractorError.invalidDataLength
            }

            let scryptParameters = try ScryptParameters(data: data)

            let scryptData: Data

            if let password = password {
                guard let passwordData = password.data(using: .utf8) else {
                    throw KeystoreExtractorError.invalidPasswordFormat
                }

                scryptData = passwordData
            } else {
                scryptData = Data()
            }

            let encryptionKey = try IRScryptKeyDeriviation()
                .deriveKey(
                    from: scryptData,
                    salt: scryptParameters.salt,
                    scryptN: UInt(scryptParameters.scryptN),
                    scryptP: UInt(scryptParameters.scryptP),
                    scryptR: UInt(scryptParameters.scryptR),
                    length: UInt(KeystoreConstants.encryptionKeyLength)
                )

            let nonceStart = ScryptParameters.encodedLength
            let nonceEnd = ScryptParameters.encodedLength + KeystoreConstants.nonceLength
            let nonce = Data(data[nonceStart ..< nonceEnd])
            let encryptedData = Data(data[nonceEnd...])

            encodedData = try NaclSecretBox.open(
                box: encryptedData,
                nonce: nonce,
                key: encryptionKey
            )
        } else {
            throw KeystoreExtractorError.unsupportedEncoding
        }

        return try decodePkcs8(data: encodedData, definition: info)
    }

    private func decodePkcs8(data: Data, definition: KeystoreDefinition) throws -> KeystoreData {
        let info = try KeystoreInfoFactory().createInfo(from: definition)

        let contentType = definition.encoding.content.count > 0 ? definition.encoding
            .content[0] : nil

        guard contentType == KeystoreEncodingContent.pkcs8.rawValue else {
            throw KeystoreExtractorError.unsupportedContent
        }

        guard data.starts(with: KeystoreConstants.pkcs8Header) else {
            throw KeystoreExtractorError.missingPkcs8Header
        }

        guard let dividerRange = data.firstRange(of: KeystoreConstants.pkcs8Divider) else {
            throw KeystoreExtractorError.missingPkcs8Divider
        }

        let secretStart = KeystoreConstants.pkcs8Header.count
        let secretEnd = dividerRange.startIndex

        let importedSecretData = Data(data[secretStart ..< secretEnd])

        let secretKeyData: Data
        switch info.cryptoType {
        case .sr25519:
            secretKeyData = try SNPrivateKey(fromEd25519: importedSecretData).rawData()
        case .ed25519:
            secretKeyData = importedSecretData
        case .ecdsa:
            secretKeyData = importedSecretData
        }

        let publicStart = dividerRange.endIndex
        let publicKeyData = Data(data[publicStart...])

        return KeystoreData(
            address: definition.address,
            secretKeyData: secretKeyData,
            publicKeyData: publicKeyData,
            cryptoType: info.cryptoType
        )
    }
}
