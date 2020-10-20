import Foundation
@testable import fearless
import IrohaCrypto
import SoraKeystore
import RobinHood

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

        let operation = AccountOperationFactory(keystore: keychain)
            .newAccountOperation(request: request, mnemonic: mnemonic)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectAccount(accountItem, settings: settings)
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

        let operation = AccountOperationFactory(keystore: keychain)
            .newAccountOperation(request: request)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectAccount(accountItem, settings: settings)
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

        let operation = AccountOperationFactory(keystore: keychain)
            .newAccountOperation(request: request)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectAccount(accountItem, settings: settings)
    }

    static func selectAccount(_ accountItem: AccountItem, settings: SettingsManagerProtocol) throws {
        let type = try SS58AddressFactory().type(fromAddress: accountItem.address)

        guard let connection = ConnectionItem.supportedConnections
            .first(where: { $0.type.rawValue == type.uint8Value }) else {
            return
        }

        var currentSettings = settings

        currentSettings.selectedAccount = accountItem
        currentSettings.selectedConnection = connection
    }
}
