import Foundation
@testable import fearless
import IrohaCrypto
import SoraKeystore
import RobinHood
import FearlessUtils

final class AccountCreationHelper {
    static func createAccountFromMnemonic(_ mnemonicString: String? = nil,
                                          cryptoType: fearless.CryptoType,
                                          name: String = "fearless",
                                          networkType: Chain = .westend,
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
                                             type: networkType,
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
                                      cryptoType: fearless.CryptoType,
                                      name: String = "fearless",
                                      networkType: Chain = .westend,
                                      derivationPath: String = "",
                                      keychain: KeystoreProtocol,
                                      settings: SettingsManagerProtocol) throws {
        let request = AccountImportSeedRequest(seed: seed,
                                               username: name,
                                               networkType: networkType,
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

        let data = try Data(contentsOf: url)

        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: data)

        let info = try AccountImportJsonFactory().createInfo(from: definition)

        return try createAccountFromKeystoreData(data,
                                                 password: password,
                                                 keychain: keychain,
                                                 settings: settings,
                                                 networkType: info.networkType ?? .westend,
                                                 cryptoType: info.cryptoType ?? .sr25519)
    }

    static func createAccountFromKeystoreData(_ data: Data,
                                              password: String,
                                              keychain: KeystoreProtocol,
                                              settings: SettingsManagerProtocol,
                                              networkType: Chain,
                                              cryptoType: fearless.CryptoType,
                                              username: String = "username") throws {
        guard let keystoreString = String(data: data, encoding: .utf8) else {
            return
        }

        let request = AccountImportKeystoreRequest(keystore: keystoreString,
                                                   password: password,
                                                   username: username,
                                                   networkType: networkType,
                                                   cryptoType: cryptoType)

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

        let currentSettings = settings

        currentSettings.selectedAccount = accountItem
        currentSettings.selectedConnection = connection
    }
}
