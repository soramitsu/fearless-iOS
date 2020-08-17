import Foundation
@testable import fearless
import IrohaCrypto
import SoraKeystore

final class AccountCreationHelper {
    static func createAccountFromMnemonic(_ mnemonicString: String? = nil,
                                   cryptoType: CryptoType,
                                   name: String = "fearless",
                                   addressType: SNAddressType = .genericSubstrate,
                                   derivationPath: String = "",
                                   keychain: KeystoreProtocol,
                                   settings: SettingsManagerProtocol) throws {
        let mnemonic: IRMnemonicProtocol

        if let mnemonicString = mnemonicString {
            mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        } else {
            mnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
        }

        let request = AccountCreationRequest(username: name,
                                             type: addressType,
                                             derivationPath: derivationPath,
                                             cryptoType: cryptoType)

        let operation = AccountOperationFactory(keystore: keychain, settings: settings)
            .newAccountOperation(request: request, mnemonic: mnemonic, connection: nil)

        OperationQueue().addOperations([operation], waitUntilFinished: true)
    }

    static func createAccountFromSeed(_ seed: String,
                               cryptoType: CryptoType,
                               name: String = "fearless",
                               addressType: SNAddressType = .genericSubstrate,
                               derivationPath: String = "",
                               keychain: KeystoreProtocol,
                               settings: SettingsManagerProtocol) throws {
        let request = AccountImportSeedRequest(seed: seed,
                                               username: name,
                                               type: addressType,
                                               derivationPath: derivationPath,
                                               cryptoType: cryptoType)

        let operation = AccountOperationFactory(keystore: keychain, settings: settings)
            .newAccountOperation(request: request, connection: nil)

        OperationQueue().addOperations([operation], waitUntilFinished: true)
    }

    static func createAccountFromKeystore(_ filename: String,
                                          password: String,
                                          keychain: KeystoreProtocol,
                                          settings: SettingsManagerProtocol) throws {
        guard let url = Bundle(for: AccountCreationHelper.self).url(forResource: filename, withExtension: "json") else {
            return
        }

        let keystoreString = try String(contentsOf: url)

        let request = AccountImportKeystoreRequest(keystore: keystoreString,
                                                   password: password,
                                                   username: nil)

        let operation = AccountOperationFactory(keystore: keychain, settings: settings)
            .newAccountOperation(request: request, connection: nil)

        OperationQueue().addOperations([operation], waitUntilFinished: true)
    }

}
