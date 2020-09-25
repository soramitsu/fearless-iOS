import Foundation
import IrohaCrypto
import SoraKeystore
import FearlessUtils

enum SigningWrapperError: Error {
    case missingSelectedAccount
    case missingSecretKey
}

final class SigningWrapper: SigningWrapperProtocol {
    let keystore: KeystoreProtocol
    let settings: SettingsManagerProtocol

    init(keystore: KeystoreProtocol, settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.settings = settings
    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        guard let selectedAccount = settings.selectedAccount else {
            throw SigningWrapperError.missingSelectedAccount
        }

        guard let secretKey = try keystore.fetchSecretKeyForAddress(selectedAccount.address) else {
            throw SigningWrapperError.missingSecretKey
        }

        switch selectedAccount.cryptoType {
        case .sr25519:
            return try signSr25519(originalData,
                                   secretKeyData: secretKey,
                                   publicKeyData: selectedAccount.publicKeyData)
        case .ed25519:
            return try signEd25519(originalData,
                                   secretKey: secretKey)
        case .ecdsa:
            return try signEcdsa(originalData,
                                 secretKey: secretKey)
        }
    }
}
