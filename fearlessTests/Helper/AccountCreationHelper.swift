import Foundation
@testable import fearless
import IrohaCrypto
import SoraKeystore
import RobinHood
import FearlessUtils

final class AccountCreationHelper {
    static func createMetaAccountFromMnemonic(
        _ mnemonicString: String? = nil,
        cryptoType: fearless.CryptoType,
        name: String = "fearless",
        derivationPath: String = "",
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        let mnemonic: IRMnemonicProtocol

        if let mnemonicString = mnemonicString {
            mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        } else {
            mnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
        }

        let request = MetaAccountCreationRequest(username: name,
                                                 substrateDerivationPath: derivationPath,
                                                 substrateCryptoType: cryptoType,
                                                 ethereumDerivationPath: "")

        let operation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request, mnemonic: mnemonic)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }

    static func createMetaAccountFromSeed(
        _ seed: String,
        cryptoType: fearless.CryptoType,
        name: String = "fearless",
        derivationPath: String = "",
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        let request = MetaAccountImportSeedRequest(seed: seed,
                                                   username: name,
                                                   substrateDerivationPath: derivationPath,
                                                   ethereumDerivationPath: "",
                                                   cryptoType: cryptoType)

        let operation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }

    static func createMetaAccountFromKeystore(
        _ filename: String,
        password: String,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        guard let url = Bundle(for: AccountCreationHelper.self)
                .url(forResource: filename, withExtension: "json") else { return }

        let data = try Data(contentsOf: url)

        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: data)

        let info = try AccountImportJsonFactory().createInfo(from: definition)
        let cryptoType = CryptoType(rawValue: info.cryptoType?.rawValue ?? CryptoType.sr25519.rawValue)

        return try createMetaAccountFromKeystoreData(
            data,
            password: password,
            keychain: keychain,
            settings: settings,
            networkType: info.networkType ?? .westend,
            cryptoType: cryptoType ?? .sr25519
        )
    }

    static func createMetaAccountFromKeystoreData(
        _ data: Data,
        password: String,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings,
        networkType: Chain,
        cryptoType: fearless.CryptoType,
        username: String = "username"
    ) throws {
        guard let keystoreString = String(data: data, encoding: .utf8) else { return }

        let request = MetaAccountImportKeystoreRequest(
            keystore: keystoreString,
            password: password,
            username: username,
            cryptoType: cryptoType
        )

        let operation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }

    static func selectMetaAccount(_ accountItem: MetaAccountModel, settings: SelectedWalletSettings) throws {
        settings.save(value: accountItem)
        settings.setup(runningCompletionIn: .global()) { _ in}
    }
}
