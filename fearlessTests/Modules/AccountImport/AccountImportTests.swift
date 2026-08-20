import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import Cuckoo
import IrohaCrypto
import SoraFoundation
import struct SSFModels.ChainAccountModel

class AccountImportTests: XCTestCase {

    func testConfirmedLegacyWalletSeedAdoptionCreatesStableAppOwnedAccounts() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let walletSeed = Data(repeating: 0, count: 32)
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            walletSeed,
            with: KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        )

        let adopter = UniversalWalletStoredSeedAdopter(keystore: keychain)
        let adopted = try adopter.adoptStoredSecret(for: wallet)
        let retried = try adopter.adoptStoredSecret(for: adopted)

        XCTAssertEqual(adopted, retried)
        XCTAssertTrue(
            UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
                in: adopted,
                for: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        )
        XCTAssertTrue(
            UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
                in: adopted,
                for: UniversalWalletRegistry.taira.chainId
            )
        )
        XCTAssertEqual(
            try keychain.fetchKey(
                for: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
            ),
            Data(UniversalWalletSeedBridge.contract.utf8)
        )
        XCTAssertEqual(
            try KeychainUniversalWalletMnemonicProvider(keystore: keychain)
                .rootMnemonic(for: adopted),
            try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: walletSeed)
        )
    }

    func testStoredRootEntropyAdoptionUsesStandardMnemonicWithoutWritingBridgeMarker() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let mnemonic = try IRMnemonicCreator().mnemonic(
            fromList: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            mnemonic.entropy(),
            with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        )

        let adopted = try UniversalWalletStoredSeedAdopter(keystore: keychain)
            .adoptStoredSecret(for: wallet)
        let address = UniversalWalletAccountAddressResolver.address(
            for: UniversalWalletRegistry.bitcoinMainnetChainModel,
            wallet: adopted
        )

        XCTAssertEqual(
            address,
            try BitcoinKeyDerivation.deriveAccount(
                mnemonic: mnemonic.toString(),
                network: .mainnet
            ).firstReceiveAddress
        )
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
            )
        )
    }

    func testLegacyWalletSeedAdoptionRejectsForeignMarkerAndInvalidSeed() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let sourceTag = KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
        let seedTag = KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        let keychain = InMemoryKeychain()
        try keychain.saveKey(Data("foreign-v2".utf8), with: sourceTag)
        try keychain.saveKey(Data(repeating: 0, count: 32), with: seedTag)

        XCTAssertThrowsError(
            try UniversalWalletStoredSeedAdopter(keystore: keychain)
                .adoptStoredSecret(for: wallet)
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletStoredSeedAdopter.AdoptionError,
                .unsupportedSecretSource
            )
        }

        try keychain.deleteKey(for: sourceTag)
        try keychain.updateKey(Data(repeating: 0, count: 31), with: seedTag)
        XCTAssertThrowsError(
            try UniversalWalletStoredSeedAdopter(keystore: keychain)
                .adoptStoredSecret(for: wallet)
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletStoredSeedAdopter.AdoptionError,
                .storedWalletSeedUnavailable
            )
        }
        XCTAssertFalse(try keychain.checkKey(for: sourceTag))
    }

    func testWalletSeedImportAutomaticallyCreatesStableSignableBitcoinAccount() throws {
        let walletSeed = Data(repeating: 0, count: 32)
        let seedHex = walletSeed.toHex(includePrefix: false)
        let expectedMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
        XCTAssertEqual(
            try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: walletSeed),
            expectedMnemonic
        )
        let expectedBitcoin = try BitcoinKeyDerivation.deriveAccount(
            mnemonic: expectedMnemonic,
            network: .mainnet
        )
        XCTAssertEqual(
            expectedBitcoin.publicKey.toHex(includePrefix: false),
            "03c5db199831f23a3a1575518c8e9e948bfd495481aac442dec64b447ee76bd6fa"
        )
        XCTAssertEqual(
            expectedBitcoin.firstReceiveAddress,
            "bc1qzmtrqsfuaf6l6kkcsseumq26ukaphfj9skkug6"
        )

        func importWallet(into keychain: InMemoryKeychain) throws -> MetaAccountModel {
            let request = MetaAccountImportSeedRequest(
                substrateSeed: seedHex,
                ethereumSeed: nil,
                username: "seed-wallet",
                substrateDerivationPath: "",
                ethereumDerivationPath: nil,
                cryptoType: .sr25519
            )
            let operation = MetaAccountOperationFactory(keystore: keychain)
                .newMetaAccountOperation(request: request, isBackuped: true)
            operation.start()
            return try operation.extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )
        }

        let firstKeychain = InMemoryKeychain()
        let firstWallet = try importWallet(into: firstKeychain)
        let firstBitcoin = try XCTUnwrap(firstWallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let firstAddress = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: UniversalWalletRegistry.bitcoinMainnetChainModel,
                wallet: firstWallet
            )
        )
        let firstTaira = try XCTUnwrap(firstWallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.isValidTairaAccount($0)
        }))

        XCTAssertEqual(firstBitcoin.publicKey, expectedBitcoin.publicKey)
        XCTAssertEqual(firstAddress, expectedBitcoin.firstReceiveAddress)
        XCTAssertEqual(
            firstTaira.publicKey.toHex(includePrefix: false),
            "2651a79b3da908fbdb63e0756e9be9561c6c4638120c3af0d444670cd088a138"
        )
        XCTAssertEqual(
            UniversalWalletChainAccountSupport.address(
                for: UniversalWalletRegistry.taira.chainId,
                publicKey: firstTaira.publicKey
            ),
            "testuﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        )
        XCTAssertEqual(
            try KeychainUniversalWalletMnemonicProvider(
                keystore: firstKeychain
            ).mnemonic(
                for: firstWallet,
                chain: UniversalWalletRegistry.bitcoinMainnetChainModel
            ),
            expectedMnemonic
        )
        XCTAssertFalse(
            try firstKeychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(firstWallet.metaId)
            ),
            "The derived app-owned mnemonic must not masquerade as the root wallet mnemonic"
        )
        XCTAssertTrue(
            try firstKeychain.checkKey(
                for: KeystoreTagV2.substrateSeedTagForMetaId(firstWallet.metaId)
            )
        )
        XCTAssertEqual(
            try firstKeychain.fetchKey(
                for: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(
                    firstWallet.metaId
                )
            ),
            Data(UniversalWalletSeedBridge.contract.utf8)
        )

        let restoredWallet = try importWallet(into: InMemoryKeychain())
        let restoredAddress = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: UniversalWalletRegistry.bitcoinMainnetChainModel,
                wallet: restoredWallet
            )
        )
        XCTAssertEqual(restoredAddress, firstAddress)
    }

    func testLegacyWalletSeedAdoptionNeverReplacesConflictingUniversalAccount() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let malformedTaira = ChainAccountModel(
            chainId: UniversalWalletRegistry.taira.chainId,
            accountId: Data(repeating: 7, count: 32),
            publicKey: Data(repeating: 7, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let conflictingWallet = wallet.replacingChainAccounts([malformedTaira])
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            Data(repeating: 0, count: 32),
            with: KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        )

        XCTAssertThrowsError(
            try UniversalWalletStoredSeedAdopter(keystore: keychain)
                .adoptStoredSecret(for: conflictingWallet)
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletStoredSeedAdopter.AdoptionError,
                .conflictingUniversalWalletAccount
            )
        }
        XCTAssertEqual(conflictingWallet.chainAccounts, [malformedTaira])
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
            )
        )
    }

    func testLegacyWalletSeedAdoptionRejectsUnrelatedValidAccountsWithoutSigner() throws {
        let existingMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let wallet = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: existingMnemonic
        )
        let originalAccounts = wallet.chainAccounts
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            Data(repeating: 0, count: 32),
            with: KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        )

        XCTAssertThrowsError(
            try UniversalWalletStoredSeedAdopter(keystore: keychain)
                .adoptStoredSecret(for: wallet)
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletStoredSeedAdopter.AdoptionError,
                .conflictingUniversalWalletAccount
            )
        }
        XCTAssertEqual(wallet.chainAccounts, originalAccounts)
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
            )
        )
    }

    func testLegacyWalletSeedAdoptionRejectsDuplicateValidBitcoinAliases() throws {
        let walletSeed = Data(repeating: 0, count: 32)
        let mnemonic = try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: walletSeed)
        let candidate = try BitcoinKeyDerivation.deriveAccount(
            mnemonic: mnemonic,
            network: .mainnet
        )
        let canonical = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            accountId: candidate.publicKey,
            publicKey: candidate.publicKey,
            cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: false
        )
        let alias = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.id,
            accountId: candidate.publicKey,
            publicKey: candidate.publicKey,
            cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: false
        )
        let wallet = AccountGenerator.generateMetaAccount(with: [canonical, alias])
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            walletSeed,
            with: KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        )

        XCTAssertThrowsError(
            try UniversalWalletStoredSeedAdopter(keystore: keychain)
                .adoptStoredSecret(for: wallet)
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletStoredSeedAdopter.AdoptionError,
                .conflictingUniversalWalletAccount
            )
        }
        XCTAssertEqual(wallet.chainAccounts, [canonical, alias])
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
            )
        )
    }

    func testBitcoinImportMetadataAllowsMnemonicOnly() {
        let wallet = AccountGenerator.generateMetaAccount()
        let presenter = AccountImportPresenter(
            wireframe: MockAccountImportWireframeProtocol(),
            interactor: MockAccountImportInteractorInputProtocol(),
            flow: .chain(
                model: UniqueChainModel(
                    meta: wallet,
                    chain: UniversalWalletRegistry.bitcoinMainnetChainModel
                )
            )
        )

        presenter.didReceiveAccountImport(
            metadata: MetaAccountImportMetadata(
                availableSources: AccountImportSource.allCases,
                defaultSource: .keystore,
                availableCryptoTypes: CryptoType.allCases,
                defaultCryptoType: .sr25519
            )
        )

        XCTAssertEqual(presenter.metadata?.availableSources, [.mnemonic])
        XCTAssertEqual(presenter.metadata?.defaultSource, .mnemonic)
        XCTAssertEqual(presenter.metadata?.availableCryptoTypes, [.ecdsa])
        XCTAssertEqual(presenter.metadata?.defaultCryptoType, .ecdsa)
        XCTAssertEqual(presenter.selectedSourceType, .mnemonic)
        XCTAssertEqual(presenter.selectedCryptoType, .ecdsa)
    }

    func testTairaImportMetadataAllowsMnemonicEd25519Only() {
        let wallet = AccountGenerator.generateMetaAccount()
        let presenter = AccountImportPresenter(
            wireframe: MockAccountImportWireframeProtocol(),
            interactor: MockAccountImportInteractorInputProtocol(),
            flow: .chain(
                model: UniqueChainModel(
                    meta: wallet,
                    chain: UniversalWalletRegistry.tairaChainModel
                )
            )
        )

        presenter.didReceiveAccountImport(
            metadata: MetaAccountImportMetadata(
                availableSources: AccountImportSource.allCases,
                defaultSource: .keystore,
                availableCryptoTypes: CryptoType.allCases,
                defaultCryptoType: .sr25519
            )
        )

        XCTAssertEqual(presenter.metadata?.availableSources, [.mnemonic])
        XCTAssertEqual(presenter.metadata?.defaultSource, .mnemonic)
        XCTAssertEqual(presenter.metadata?.availableCryptoTypes, [.ed25519])
        XCTAssertEqual(presenter.metadata?.defaultCryptoType, .ed25519)
        XCTAssertEqual(presenter.selectedSourceType, .mnemonic)
        XCTAssertEqual(presenter.selectedCryptoType, .ed25519)
    }

    func testTairaMnemonicImportCreatesI105AccountAndStoresSignerEntropy() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let wallet = AccountGenerator.generateMetaAccount()
        let mnemonicString = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: wallet.name,
            derivationPath: "",
            cryptoType: .ed25519,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.taira.chainId
        )

        let operation = operationFactory.importChainAccountOperation(request: request)
        operation.start()
        let updatedWallet = try operation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let account = try XCTUnwrap(updatedWallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.taira.chainId
            )
        }))
        let address = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: UniversalWalletRegistry.tairaChainModel,
                wallet: updatedWallet
            )
        )

        XCTAssertEqual(account.chainId, UniversalWalletRegistry.taira.chainId)
        XCTAssertEqual(account.cryptoType, CryptoType.ed25519.rawValue)
        XCTAssertEqual(account.publicKey.count, 32)
        XCTAssertNoThrow(
            try IrohaAddressCodec.parse(
                address,
                expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
            )
        )
        XCTAssertTrue(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: account.accountId
                )
            )
        )
        XCTAssertEqual(
            try KeychainUniversalWalletMnemonicProvider(keystore: keychain).mnemonic(
                for: updatedWallet,
                chain: UniversalWalletRegistry.tairaChainModel
            ),
            mnemonicString
        )
    }

    func testTairaSeedImportFailsClosedWithoutMutatingWallet() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let wallet = AccountGenerator.generateMetaAccount()
        let request = ChainAccountImportSeedRequest(
            seed: String(repeating: "01", count: 32),
            username: wallet.name,
            derivationPath: "",
            cryptoType: .ed25519,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.taira.chainId
        )

        let operation = operationFactory.importChainAccountOperation(request: request)
        operation.start()

        XCTAssertThrowsError(
            try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        ) { error in
            guard case AccountOperationFactoryError.unsupportedNetwork = error else {
                return XCTFail("Expected Taira seed import to fail closed, got \(error)")
            }
        }
        XCTAssertTrue(wallet.chainAccounts.isEmpty)
    }

    func testTairaMnemonicImportRestoresSignerWithoutChangingExistingAddress() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let mnemonicString = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let wallet = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: mnemonicString
        )
        let originalAccount = try XCTUnwrap(wallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.isValidTairaAccount($0)
        }))
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: mnemonicString),
            username: wallet.name,
            derivationPath: "",
            cryptoType: .ed25519,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.taira.chainId
        )

        let operation = operationFactory.importChainAccountOperation(request: request)
        operation.start()
        let updatedWallet = try operation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let restoredAccount = try XCTUnwrap(updatedWallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.isValidTairaAccount($0)
        }))

        XCTAssertEqual(restoredAccount, originalAccount)
        XCTAssertTrue(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: originalAccount.accountId
                )
            )
        )
    }

    func testTairaMnemonicImportRejectsAddressReplacementAndPreservesSigner() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let originalMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let replacementMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let wallet = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: originalMnemonic
        )
        let originalAccount = try XCTUnwrap(wallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.isValidTairaAccount($0)
        }))
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(
            wallet.metaId,
            accountId: originalAccount.accountId
        )
        let existingEntropy = Data("existing-taira-signer".utf8)
        try keychain.saveKey(existingEntropy, with: entropyTag)
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: replacementMnemonic),
            username: wallet.name,
            derivationPath: "",
            cryptoType: .ed25519,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.taira.chainId
        )

        let operation = operationFactory.importChainAccountOperation(request: request)
        operation.start()

        XCTAssertThrowsError(
            try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        ) { error in
            guard case AccountCreateError.duplicated = error else {
                return XCTFail("Expected Taira address replacement to be rejected, got \(error)")
            }
        }
        XCTAssertEqual(try keychain.fetchKey(for: entropyTag), existingEntropy)
        XCTAssertEqual(
            wallet.chainAccounts.first(where: {
                UniversalWalletChainAccountSupport.isValidTairaAccount($0)
            }),
            originalAccount
        )
    }

    func testTairaKeystoreImportFailsBeforeParsingOrKeychainWrite() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let wallet = AccountGenerator.generateMetaAccount()
        let sentinelTag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        let sentinel = Data("existing-root-entropy".utf8)
        try keychain.saveKey(sentinel, with: sentinelTag)
        let request = ChainAccountImportKeystoreRequest(
            keystore: "not-json",
            password: "ignored",
            username: wallet.name,
            cryptoType: .ed25519,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.taira.chainId
        )

        let operation = operationFactory.importChainAccountOperation(request: request)
        operation.start()

        XCTAssertThrowsError(
            try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        ) { error in
            guard case AccountOperationFactoryError.unsupportedNetwork = error else {
                return XCTFail("Expected Taira keystore import to fail before parsing, got \(error)")
            }
        }
        XCTAssertEqual(try keychain.fetchKey(for: sentinelTag), sentinel)
        XCTAssertTrue(wallet.chainAccounts.isEmpty)
    }

    func testBitcoinMnemonicImportCreatesSignableBIP84Account() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let wallet = AccountGenerator.generateMetaAccount()
        let mnemonicString = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: wallet.name,
            derivationPath: "",
            cryptoType: .ecdsa,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId
        )

        let operation = operationFactory.importChainAccountOperation(request: request)
        operation.start()
        let updatedWallet = try operation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let account = try XCTUnwrap(updatedWallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let address = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: UniversalWalletRegistry.bitcoinMainnetChainModel,
                wallet: updatedWallet
            )
        )

        XCTAssertEqual(account.chainId, UniversalWalletRegistry.bitcoinMainnet.chainId)
        XCTAssertEqual(account.publicKey.count, 33)
        XCTAssertTrue(address.hasPrefix("bc1q"))
        XCTAssertTrue(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: account.accountId
                )
            )
        )
        XCTAssertEqual(
            try KeychainUniversalWalletMnemonicProvider(keystore: keychain).mnemonic(
                for: updatedWallet,
                chain: UniversalWalletRegistry.bitcoinMainnetChainModel
            ),
            mnemonicString
        )
    }

    func testBitcoinMnemonicImportRestoresSignerWithoutChangingExistingAddress() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let mnemonicString = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: mnemonicString
        )
        let originalAccount = try XCTUnwrap(wallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: mnemonicString),
            username: wallet.name,
            derivationPath: "",
            cryptoType: .ecdsa,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId
        )

        let operation = operationFactory.importChainAccountOperation(request: request)
        operation.start()
        let updatedWallet = try operation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let restoredAccount = try XCTUnwrap(updatedWallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))

        XCTAssertEqual(restoredAccount.publicKey, originalAccount.publicKey)
        XCTAssertTrue(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: originalAccount.accountId
                )
            )
        )
    }

    func testBitcoinMnemonicImportRejectsAddressReplacementAndPreservesSigner() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let originalMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let replacementMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: originalMnemonic
        )
        let originalAccount = try XCTUnwrap(wallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(
            wallet.metaId,
            accountId: originalAccount.accountId
        )
        let existingEntropy = Data("existing-signer".utf8)
        try keychain.saveKey(existingEntropy, with: entropyTag)
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: replacementMnemonic),
            username: wallet.name,
            derivationPath: "",
            cryptoType: .ecdsa,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId
        )

        let operation = operationFactory.importChainAccountOperation(request: request)
        operation.start()

        XCTAssertThrowsError(
            try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        ) { error in
            guard case AccountCreateError.duplicated = error else {
                return XCTFail("Expected address replacement to be rejected, got \(error)")
            }
        }
        XCTAssertEqual(try keychain.fetchKey(for: entropyTag), existingEntropy)
        XCTAssertEqual(
            wallet.chainAccounts.first(where: {
                UniversalWalletChainAccountSupport.chainId(
                    $0.chainId,
                    matches: UniversalWalletRegistry.bitcoinMainnet.chainId
                )
            })?.publicKey,
            originalAccount.publicKey
        )
    }

    func testBitcoinTestnetMnemonicImportFailsWithoutKeychainWrite() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let wallet = AccountGenerator.generateMetaAccount()
        let mnemonicString = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        let derivedTestnetAccount = try BitcoinKeyDerivation.deriveAccount(
            mnemonic: mnemonicString,
            network: .testnet
        )
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(
            wallet.metaId,
            accountId: derivedTestnetAccount.publicKey
        )
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: wallet.name,
            derivationPath: "",
            cryptoType: .ecdsa,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.bitcoinTestnet.chainId
        )

        let operation = operationFactory.importChainAccountOperation(request: request)
        operation.start()

        XCTAssertThrowsError(
            try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        ) { error in
            guard case AccountOperationFactoryError.unsupportedNetwork = error else {
                return XCTFail("Expected testnet import to fail closed, got \(error)")
            }
        }
        XCTAssertFalse(try keychain.checkKey(for: entropyTag))
    }

    func testMnemonicRestore() {
        // given

        let view = MockAccountImportViewProtocol()
        let wireframe = MockAccountImportWireframeProtocol()

        let storageFacade = UserDataStorageTestFacade()

        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )

        let repository = AccountRepositoryFactory(
            storageFacade: storageFacade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])

        let eventCenter = MockEventCenterProtocol()

        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)

        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

        let interactor = AccountImportInteractor(
            accountOperationFactory: operationFactory,
            accountRepository: AnyDataProviderRepository(repository),
            operationManager: OperationManager(),
            settings: settings,
            keystoreImportService: keystoreImportService,
            eventCenter: eventCenter,
            defaultSource: .mnemonic
        )

        let expectedUsername = "myname"
        let expectedMnemonic = "great fog follow obtain oyster raw patient extend use mirror fix balance blame sudden vessel"

        let presenter = AccountImportPresenter(wireframe: wireframe,
                                               interactor: interactor,
                                               flow: .wallet(step: .substrate))
        interactor.presenter = presenter
        presenter.view = view

        let setupExpectation = XCTestExpectation()
        setupExpectation.expectedFulfillmentCount = 2

        var sourceInputViewModel: InputViewModelProtocol?
        var usernameViewModel: InputViewModelProtocol?

        stub(view) { stub in
            when(stub.controller.get).thenReturn(UIViewController())
            when(stub.didCompleteSourceTypeSelection()).thenDoNothing()
            when(stub.didCompleteCryptoTypeSelection()).thenDoNothing()
            when(stub.didValidateSubstrateDerivationPath(any(FieldStatus.self))).thenDoNothing()
            when(stub.didValidateEthereumDerivationPath(any(FieldStatus.self))).thenDoNothing()
            when(stub.didChangeState(any(ErrorPresentableInputField.State.self))).thenDoNothing()
            when(stub.isSetup.get).thenReturn(false, true)

            when(stub.setSource(viewModel: any(InputViewModelProtocol.self))).then { viewModel in
                sourceInputViewModel = viewModel

                setupExpectation.fulfill()
            }

            when(stub.setName(viewModel: any(InputViewModelProtocol.self), visible: any(Bool.self))).then { result in
                usernameViewModel = result.0

                setupExpectation.fulfill()
            }

            when(stub.setSelectedCrypto(model: any(SelectableViewModel<TitleWithSubtitleViewModel>.self))).thenDoNothing()
            when(stub.setSource(type: any(AccountImportSource.self), chainType: any(AccountCreateChainType.self), selectable: any(Bool.self))).thenDoNothing()
            when(stub.bind(substrateViewModel: any(InputViewModelProtocol.self))).thenDoNothing()
            when(stub.bind(ethereumViewModel: any(InputViewModelProtocol.self))).thenDoNothing()
            when(stub.show(chainType: any(AccountCreateChainType.self))).thenDoNothing()
        }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.proceed(from: any(AccountImportViewProtocol?.self),
                               flow: any(AccountImportFlow.self))).then { _ in
                expectation.fulfill()
            }
        }

        let completeExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is SelectedAccountChanged {
                    completeExpectation.fulfill()
                }
            }
        }

        // when

        presenter.setup()

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        _ = sourceInputViewModel?.inputHandler.didReceiveReplacement(expectedMnemonic,
                                                                     for: NSRange(location: 0, length: 0));
        presenter.validateInput(value: expectedMnemonic)

        _ = usernameViewModel?.inputHandler.didReceiveReplacement(expectedUsername,
                                                                  for: NSRange(location: 0, length: 0))

        presenter.proceed()

        // then

        wait(for: [expectation, completeExpectation], timeout: 10)

        guard let selectedAccount = settings.value else {
            XCTFail("Unexpected empty account")
            return
        }

        XCTAssertEqual(selectedAccount.name, expectedUsername)

        let metaId = selectedAccount.metaId

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.entropyTagForMetaId(metaId)))

        XCTAssertFalse(try keychain.checkKey(for: KeystoreTagV2.substrateDerivationTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)))

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId)))

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.substrateSeedTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumSeedTagForMetaId(metaId)))
    }
}
