import Foundation
@testable import fearless
import IrohaCrypto
import SoraKeystore
import RobinHood
import SSFUtils
import SSFCrypto
import SSFModels

final class AccountCreationHelper {
    static func createMetaAccountFromMnemonic(
        _ mnemonicString: String? = nil,
        cryptoType: CryptoType,
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

        let request = MetaAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: username,
            substrateDerivationPath: substrateDerivationPath,
            ethereumDerivationPath: ethereumDerivationPath,
            cryptoType: cryptoType,
            defaultChainId: nil
        )

        let operation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request, isBackuped: true)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }

    static func createMetaAccountFromSeed(
        substrateSeed: String,
        ethereumSeed: String?,
        cryptoType: CryptoType,
        username: String = "fearless",
        substrateDerivationPath: String = "",
        ethereumDerivationPath: String? = nil,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        let resolvedEthereumDerivationPath: String? = {
            guard ethereumSeed != nil else {
                return nil
            }

            return ethereumDerivationPath ?? DerivationPathConstants.defaultEthereum
        }()

        let request = MetaAccountImportSeedRequest(substrateSeed: substrateSeed,
                                                   ethereumSeed: ethereumSeed,
                                                   username: username,
                                                   substrateDerivationPath: substrateDerivationPath,
                                                   ethereumDerivationPath: resolvedEthereumDerivationPath,
                                                   cryptoType: cryptoType)

        let operation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request, isBackuped: true)

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
        cryptoType: CryptoType,
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
            .newMetaAccountOperation(request: request, isBackuped: true)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }

    static func selectMetaAccount(_ accountItem: fearless.MetaAccountModel, settings: SelectedWalletSettings) throws {
        let saveSemaphore = DispatchSemaphore(value: 0)
        var saveResult: Result<fearless.MetaAccountModel, Error>?

        settings.save(value: accountItem, runningCompletionIn: nil) { result in
            saveResult = result
            saveSemaphore.signal()
        }

        _ = saveSemaphore.wait(timeout: .now() + 5)

        switch saveResult {
        case .success:
            break
        case let .failure(error):
            throw error
        case .none:
            throw BaseOperationError.parentOperationCancelled
        }

        let setupSemaphore = DispatchSemaphore(value: 0)
        var setupResult: Result<fearless.MetaAccountModel?, Error>?

        settings.setup(runningCompletionIn: nil) { result in
            setupResult = result
            setupSemaphore.signal()
        }

        _ = setupSemaphore.wait(timeout: .now() + 5)

        switch setupResult {
        case .success:
            break
        case let .failure(error):
            throw error
        case .none:
            throw BaseOperationError.parentOperationCancelled
        }
    }
}
