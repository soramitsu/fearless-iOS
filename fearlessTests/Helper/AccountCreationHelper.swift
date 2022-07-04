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
        username: String = "fearless",
        substrateDerivationPath: String = "",
        ethereumDerivationPath: String = DerivationPathConstants.defaultEthereum,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        let mnemonic: IRMnemonicProtocol

        if let mnemonicString = mnemonicString {
            mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        } else {
            mnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
        }

        let request = MetaAccountImportMnemonicRequest(mnemonic: mnemonic,
                                                       username: username,
                                                       substrateDerivationPath: substrateDerivationPath,
                                                       ethereumDerivationPath: ethereumDerivationPath,
                                                       cryptoType: cryptoType)

        let operation = MetaAccountOperationFactory(keystore: keychain).newMetaAccountOperation(request: request)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }

    static func createMetaAccountFromSeed(
        substrateSeed: String,
        ethereumSeed: String?,
        cryptoType: fearless.CryptoType,
        username: String = "fearless",
        substrateDerivationPath: String = "",
        ethereumDerivationPath: String? = nil,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        let request = MetaAccountImportSeedRequest(substrateSeed: substrateSeed,
                                                   ethereumSeed: ethereumSeed,
                                                   username: username,
                                                   substrateDerivationPath: substrateDerivationPath,
                                                   ethereumDerivationPath: ethereumDerivationPath,
                                                   cryptoType: cryptoType)

        let operation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }

    static func createMetaAccountFromKeystore(
        substrateFilename: String,
        ethereumFilename: String?,
        substratePassword: String,
        ethereumPassword: String?,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        guard let substrateUrl = Bundle(for: AccountCreationHelper.self)
                .url(forResource: substrateFilename, withExtension: "json") else { return }
        let substrateData = try Data(contentsOf: substrateUrl)
        
        let ethereumData: Data?
        if let ethereumFilename = ethereumFilename,
            let ethereumUrl = Bundle(for: AccountCreationHelper.self).url(forResource: ethereumFilename, withExtension: "json") {
            ethereumData = try? Data(contentsOf: ethereumUrl)
        } else {
            ethereumData = nil
        }

        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: substrateData)

        let info = try AccountImportJsonFactory().createInfo(from: definition)
        let cryptoType = CryptoType(rawValue: info.cryptoType?.rawValue ?? CryptoType.sr25519.rawValue)

        return try createMetaAccountFromKeystoreData(substrateData: substrateData,
                                                     ethereumData: ethereumData,
                                                     substratePassword: substratePassword,
                                                     ethereumPassword: ethereumPassword,
                                                     keychain: keychain,
                                                     settings: settings,
                                                     cryptoType: cryptoType ?? .sr25519)
    }

    static func createMetaAccountFromKeystoreData(
        substrateData: Data,
        ethereumData: Data?,
        substratePassword: String,
        ethereumPassword: String?,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings,
        cryptoType: fearless.CryptoType,
        username: String = "username"
    ) throws {
        guard let substrateKeystoreString = String(data: substrateData, encoding: .utf8) else { return }
        let ethereumKeystoreString: String?
        if let ethereumData = ethereumData {
            ethereumKeystoreString = String(data: ethereumData, encoding: .utf8)
        } else {
            ethereumKeystoreString = nil
        }

        let request = MetaAccountImportKeystoreRequest(substrateKeystore: substrateKeystoreString,
                                                       ethereumKeystore: ethereumKeystoreString,
                                                       substratePassword: substratePassword,
                                                       ethereumPassword: ethereumPassword,
                                                       username: username,
                                                       cryptoType: cryptoType)

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
