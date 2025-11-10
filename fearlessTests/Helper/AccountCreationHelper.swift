import Foundation
@testable import fearless
import IrohaCrypto
import SoraKeystore
import RobinHood
import SSFUtils

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
