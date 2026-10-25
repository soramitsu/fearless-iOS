import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import Cuckoo
import CoreData
import AVFoundation
import SSFCloudStorage
import SSFQRService
import IrohaCrypto
import SoraFoundation
import struct SSFModels.ChainAccountModel
import class SSFModels.ChainModel

private let nativeTonRecoveryFixture = "cluster notice abandon frost gospel boring element situate click mix vague replace imitate garment useful crater resource dose tenant theme foam ancient phrase slight"

// Public IC07 observations from the exact released 4.0.4 factory, not current derivation.
// Frozen origin: ios-historical-ton-v1/writer-documents-v1-27-0/historical-state.json.
private let historicalTypedTonRecoveryCases: [(name: String, phrase: String, publicKey: String)] = [
    ("GW-T2a", nativeTonRecoveryFixture.replacingOccurrences(of: "abandon frost", with: "abandon  frost"),
     "2d4279cae4f717c80f4b56f4d67b6c189d5fcd260a2a75673c8014fd41da2ea3"),
    ("GW-T2b", nativeTonRecoveryFixture + " ",
     "f14148c55ccec237ef9d9f23b42e7e76faf019814c5001326433c7e64c09abcb"),
    ("GW-T2c", " " + nativeTonRecoveryFixture,
     "b9588e31c14c27cb4826927f2b8a0a0037823e7c619391bfc1435aa5d73930c7"),
    ("GW-T2e", nativeTonRecoveryFixture.replacingOccurrences(of: "replace imitate", with: "replace\nimitate"),
     "b16e6d3125e0112bd863148b12cf978beb31d6a54bb21998fea1a0d6cf8eebef"),
    ("GW-T2f", nativeTonRecoveryFixture.replacingOccurrences(of: "abandon frost", with: "abandon  frost")
        .replacingOccurrences(of: "click mix", with: "click  mix") + " ",
     "3a549170be054e76b1dec7ec3f8e64724f1946d9681eeb8038176a9744598c1f")]

class AccountImportTests: XCTestCase {
    private func nativeTonRecoveryOperation(_ keychain: KeystoreProtocol) throws -> BaseOperation<MetaAccountModel> {
        MetaAccountOperationFactory(keystore: keychain).newMetaAccountOperation(
            request: MetaAccountImportMnemonicRequest(
                mnemonic: try LegacyTonMnemonic.validatedForImport(nativeTonRecoveryFixture),
                username: "Restored TON", substrateDerivationPath: "",
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: .sr25519, defaultChainId: nil
            ), isBackuped: true
        )
    }

    func testAmbiguousNativeTonImportCannotSilentlySelectAnotherHistoricalIdentity() throws {
        for item in historicalTypedTonRecoveryCases {
            let keychain = NativeTonRecoveryTestKeychain()
            keychain.values["older-wallet-secret"] = Data([9, 8, 7])
            let operation = LegacyTonAccountImportOperation(
                keystore: keychain, phrase: item.phrase, username: item.name, isBackuped: true
            )
            operation.start()
            if case let .success(wallet)? = operation.result {
                let actual = wallet.legacyTonAccount?.publicKey.toHex(includePrefix: false) ?? "missing"
                XCTFail("\(item.name) silently imported \(actual); original \(item.publicKey) requires explicit choice")
            }
            XCTAssertEqual(Set(keychain.values.keys), ["older-wallet-secret"], "No writes before candidate selection")
            try operation.rollbackKeychainChanges()
            XCTAssertEqual(keychain.values, ["older-wallet-secret": Data([9, 8, 7])])
        }
    }

    func testNativeTonInputPreservesTypedBytesBeforeCandidateSelection() {
        for item in historicalTypedTonRecoveryCases {
            let presenter = AccountImportPresenter(
                wireframe: MockAccountImportWireframeProtocol(), interactor: MockAccountImportInteractorInputProtocol(),
                flow: .wallet(step: .substrate)
            )
            presenter.didReceiveAccountImport(metadata: MetaAccountImportMetadata(
                availableSources: AccountImportSource.allCases, defaultSource: .legacyTonMnemonic,
                availableCryptoTypes: CryptoType.allCases, defaultCryptoType: .sr25519
            ))
            presenter.sourceViewModel?.inputHandler.changeValue(to: item.phrase)
            XCTAssertEqual(presenter.sourceViewModel?.inputHandler.normalizedValue, item.phrase, item.name)
        }
    }

    func testExplicitNativeTonCandidateReproducesHistoricalIdentityAndExactBytes() throws {
        for item in historicalTypedTonRecoveryCases {
            let candidates = try LegacyTonMnemonic.importCandidates(item.phrase)
            XCTAssertEqual(candidates.count, 2, item.name)
            XCTAssertEqual(candidates[0].publicKey.toHex(includePrefix: false), item.publicKey)
            XCTAssertEqual(candidates[0].phrase, item.phrase)
            XCTAssertEqual(candidates[1].publicKey.toHex(includePrefix: false),
                           "34eb4b67d64f74d989ce2bc2e3dfddb7ed4cb0eec92f29fbecd05b1eabab0254")
            XCTAssertEqual(candidates[1].address, "UQDd4MlN_A6WTKFTKGXIlS9SytvKo5A8E1ws429SmjCPbIbM")
            for candidate in candidates {
                let keychain = NativeTonRecoveryTestKeychain()
                keychain.values["older-wallet-secret"] = Data([9, 8, 7])
                let operation = MetaAccountOperationFactory(keystore: keychain).newMetaAccountOperation(
                    request: MetaAccountImportMnemonicRequest(
                        mnemonic: candidate.mnemonic, username: item.name, substrateDerivationPath: "",
                        ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                        cryptoType: .sr25519, defaultChainId: nil
                    ), isBackuped: true
                )
                operation.start()
                let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                let native = try XCTUnwrap(wallet.legacyTonAccount)
                XCTAssertEqual(native.publicKey, candidate.publicKey)
                XCTAssertEqual(native.address, candidate.address)
                XCTAssertEqual(try keychain.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)),
                               Data(candidate.phrase.utf8))
                let credentials = try native.signingCredentials(keystore: keychain, metaId: wallet.metaId)
                XCTAssertEqual(try native.validatedPrivateKey(XCTUnwrap(credentials.legacyNativePrivateKey)).count, 64)
                try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
                XCTAssertEqual(keychain.values, ["older-wallet-secret": Data([9, 8, 7])])
            }
        }
    }

    func testNativeTonCandidateSelectionCannotBindCanonicalKeyToTypedPhrase() throws {
        let phrase = historicalTypedTonRecoveryCases[0].phrase
        let candidates = try LegacyTonMnemonic.importCandidates(phrase)
        let keychain = NativeTonRecoveryTestKeychain()
        let operation = LegacyTonAccountImportOperation(
            keystore: keychain, phrase: phrase, username: "Wrong selection", isBackuped: true,
            selectedPublicKey: candidates[1].publicKey
        )
        operation.start()
        XCTAssertThrowsError(try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
        XCTAssertTrue(keychain.values.isEmpty)
        let titleCase = "Cluster" + nativeTonRecoveryFixture.dropFirst("cluster".count)
        let sameIdentity = try LegacyTonMnemonic.importCandidates(titleCase)
        XCTAssertEqual(sameIdentity.count, 1)
        XCTAssertEqual(try LegacyTonMnemonic.validatedForImport(titleCase).toString(), titleCase)
    }

    func testNativeTonRecoveryKeepsExactIdentityPhraseAndIndependentLegacySecrets() throws {
        let keychain = NativeTonRecoveryTestKeychain()
        keychain.values["older-wallet-secret"] = Data([9, 8, 7])
        let operation = try nativeTonRecoveryOperation(keychain)
        operation.start()
        let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let legacy = try XCTUnwrap(wallet.legacyTonAccount)
        XCTAssertEqual(legacy.publicKey.toHex(includePrefix: false), "34eb4b67d64f74d989ce2bc2e3dfddb7ed4cb0eec92f29fbecd05b1eabab0254")
        XCTAssertNil(wallet.substrateAccountId)
        XCTAssertNil(wallet.substratePublicKey)
        XCTAssertNil(wallet.ethereumPublicKey)
        XCTAssertTrue(wallet.chainAccounts.isEmpty)
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        let keyTag = KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)
        XCTAssertEqual(try keychain.fetchKey(for: entropyTag), Data(nativeTonRecoveryFixture.utf8))
        XCTAssertEqual(try legacy.validatedPrivateKey(keychain.fetchKey(for: keyTag)).count, 64)
        XCTAssertEqual(try legacy.mnemonic(from: keychain.fetchKey(for: entropyTag)).toString(), nativeTonRecoveryFixture)
        (operation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        XCTAssertTrue(try keychain.checkKey(for: keyTag))
        XCTAssertEqual(keychain.values["older-wallet-secret"], Data([9, 8, 7]))
    }

    func testNativeTonRecoveryRetainsReleasedShortPhraseSupport() throws {
        // Public vector cross-checked with @ton/crypto native mnemonic derivation.
        let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon ankle"
        let keychain = NativeTonRecoveryTestKeychain()
        let operation = LegacyTonAccountImportOperation(
            keystore: keychain, phrase: phrase, username: "Older import", isBackuped: true
        )
        operation.start()
        let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertEqual(wallet.legacyTonAccount?.publicKey.toHex(includePrefix: false),
                       "f6e89217cdc90b46e58d646b9616b7c163ed87911ebd1783b209c3595749a469")
        XCTAssertEqual(try keychain.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)), Data(phrase.utf8))
        try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        XCTAssertTrue(keychain.values.isEmpty)
    }

    func testNativeTonRecoveryRejectsInvalidOrOrdinaryBip39PhraseBeforeWriting() {
        XCTAssertThrowsError(try LegacyTonMnemonic.validatedForImport("not a recovery phrase"))
        let keychain = NativeTonRecoveryTestKeychain()
        let operation = LegacyTonAccountImportOperation(
            keystore: keychain,
            phrase: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
            username: "Incorrect format", isBackuped: true
        )
        operation.start()
        XCTAssertThrowsError(try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
        XCTAssertTrue(keychain.values.isEmpty)
    }

    func testNativeTonRecoveryRollsBackPartialSecretWritesAndCanRetry() throws {
        let keychain = NativeTonRecoveryTestKeychain()
        keychain.values["legacy-existing"] = Data([42])
        keychain.failOnAddNumber = 2
        let failed = try nativeTonRecoveryOperation(keychain)
        failed.start()
        XCTAssertThrowsError(try failed.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
        XCTAssertEqual(keychain.values, ["legacy-existing": Data([42])])
        keychain.failOnAddNumber = nil
        let retry = try nativeTonRecoveryOperation(keychain)
        retry.start()
        _ = try retry.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        try (retry as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        XCTAssertEqual(keychain.values, ["legacy-existing": Data([42])])
    }

    @MainActor
    func testExplicitNativeTonImportRoutesToNativeFactoryWithoutSubstrateDerivation() async throws {
        let interactor = MockAccountImportInteractorInputProtocol()
        var imported: MetaAccountImportRequest?
        stub(interactor) { stub in
            when(stub.importMetaAccount(request: any())).then { imported = $0 }
            when(stub.setup()).thenDoNothing()
        }
        let presenter = AccountImportPresenter(
            wireframe: MockAccountImportWireframeProtocol(), interactor: interactor,
            flow: .wallet(step: .substrate)
        )
        let controller = AccountImportViewController(presenter: presenter)
        presenter.view = controller
        let (window, _) = try tonHost(controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        presenter.didReceiveAccountImport(metadata: MetaAccountImportMetadata(
            availableSources: AccountImportSource.allCases, defaultSource: .legacyTonMnemonic,
            availableCryptoTypes: CryptoType.allCases, defaultCryptoType: .sr25519
        ))
        presenter.sourceViewModel?.inputHandler.changeValue(to: nativeTonRecoveryFixture)
        presenter.usernameViewModel?.inputHandler.changeValue(to: "Restored TON")
        XCTAssertNil(presenter.substrateDerivationPathViewModel)
        XCTAssertNil(presenter.ethereumDerivationPathViewModel)
        presenter.proceed()
        await tonWait { imported != nil }
        guard case let .mnemonic(data)? = imported?.source else { return XCTFail("Native recovery was not routed") }
        XCTAssertTrue(data.mnemonic is LegacyTonMnemonic)
        XCTAssertEqual(data.mnemonic.toString(), nativeTonRecoveryFixture)
        verify(interactor, never()).createMnemonicFromString(any())
    }

    func testAddingNativeTonWalletRollsBackSecretsWhenWalletStoreFails() throws {
        let keychain = NativeTonRecoveryTestKeychain()
        keychain.values["existing-wallet"] = Data([6])
        let storageFacade = AlwaysFailingAccountImportStorageFacade()
        let settings = SelectedWalletSettings(storageFacade: storageFacade, operationQueue: OperationQueue())
        let repository = AccountRepositoryFactory(storageFacade: storageFacade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        let interactor = AddAccount.AccountImportInteractor(
            accountOperationFactory: MetaAccountOperationFactory(keystore: keychain),
            accountRepository: AnyDataProviderRepository(repository), operationManager: OperationManager(),
            settings: settings, keystoreImportService: KeystoreImportService(logger: Logger.shared),
            eventCenter: MockEventCenterProtocol(), defaultSource: .legacyTonMnemonic
        )
        let output = MockAccountImportInteractorOutputProtocol()
        interactor.presenter = output
        let failure = expectation(description: "Native import store failure")
        stub(output) { stub in
            when(stub.didReceiveAccountImport(error: any())).then { _ in failure.fulfill() }
            when(stub.didCompleteAccountImport()).then { XCTFail("Failed import was marked complete") }
        }
        let operation = try nativeTonRecoveryOperation(keychain)
        interactor.importAccountUsingOperation(operation)
        wait(for: [failure], timeout: 10)
        XCTAssertNil(settings.value)
        XCTAssertEqual(keychain.values, ["existing-wallet": Data([6])])
    }

    private func makeMnemonicWalletIdentity(
        mnemonicString: String,
        chainAccounts: Set<ChainAccountModel> = []
    ) throws -> MetaAccountModel {
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        let operation = MetaAccountOperationFactory(keystore: InMemoryKeychain())
            .newMetaAccountOperation(
                request: MetaAccountImportMnemonicRequest(
                    mnemonic: mnemonic,
                    username: "Universal wallet",
                    substrateDerivationPath: "",
                    ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                    cryptoType: .sr25519,
                    defaultChainId: nil
                ),
                isBackuped: true
            )
        operation.start()
        let wallet = try operation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        return wallet.replacingChainAccounts(chainAccounts)
    }

    func testTextViewDidChangeSynchronizesSourceViewModelAndPresenterInput() {
        let expectedInput = String(repeating: "ab", count: 32)
        let inputHandler = InputHandler(required: true)
        let sourceViewModel = InputViewModel(inputHandler: inputHandler)
        let presenter = MockAccountImportPresenterProtocol()

        stub(presenter) { stub in
            when(stub.flow.get).thenReturn(.wallet(step: .substrate))
            when(stub.setup()).thenDoNothing()
            when(stub.validateInput(value: any())).thenDoNothing()
        }

        let viewController = AccountImportViewController(presenter: presenter)
        viewController.loadViewIfNeeded()
        viewController.setSource(viewModel: sourceViewModel)
        viewController.rootView.textView.text = expectedInput

        viewController.textViewDidChange(viewController.rootView.textView)

        XCTAssertEqual(inputHandler.value, expectedInput)
        verify(presenter, times(1)).validateInput(value: equal(to: expectedInput))
    }

    func testMarkedRawWalletSeedBridgeRepairsStableAppOwnedAccounts() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let walletSeed = Data(repeating: 0, count: 32)
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            walletSeed,
            with: KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        )
        try keychain.saveKey(
            Data(UniversalWalletSeedBridge.contract.utf8),
            with: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
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

    func testUnmarkedLegacyWalletSeedRequiresOriginalRecoveryPhrase() throws {
        let wallet = AccountGenerator.generateMetaAccount()
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
                .storedWalletSeedUnavailable
            )
        }
        XCTAssertTrue(wallet.chainAccounts.isEmpty)
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
            )
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

    func testMalformedStoredRootEntropyRoutesToExplicitRecovery() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            Data(repeating: 0, count: 31),
            with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        )

        XCTAssertThrowsError(
            try UniversalWalletStoredSeedAdopter(keystore: keychain)
                .adoptStoredSecret(for: wallet)
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletStoredSeedAdopter.AdoptionError,
                .storedWalletSeedUnavailable
            )
        }
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
            let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
            try AccountCreationHelper.selectMetaAccount(wallet, settings: settings,
                importOperation: operation as? PersistenceBoundKeychainOperation)
            return wallet
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

    func testMarkedRawSeedBridgeRejectsAccountsFromDifferentPhrase() throws {
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
        try keychain.saveKey(
            Data(UniversalWalletSeedBridge.contract.utf8),
            with: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
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
        XCTAssertEqual(
            try keychain.fetchKey(
                for: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
            ),
            Data(UniversalWalletSeedBridge.contract.utf8)
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
        try keychain.saveKey(
            Data(UniversalWalletSeedBridge.contract.utf8),
            with: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
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
        XCTAssertEqual(
            try keychain.fetchKey(
                for: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
            ),
            Data(UniversalWalletSeedBridge.contract.utf8)
        )
    }

    func testBitcoinRootRecoveryAllowsOnlyWalletMnemonic() {
        let wallet = AccountGenerator.generateMetaAccount()
        let view = MockAccountImportViewProtocol()
        var sourceSelectionEnabled: Bool?
        stub(view) { stub in
            stub.setSource(viewModel: any(InputViewModelProtocol.self)).thenDoNothing()
            stub.setName(
                viewModel: any(InputViewModelProtocol.self),
                visible: any(Bool.self)
            ).thenDoNothing()
            stub.setSource(
                type: any(AccountImportSource.self),
                chainType: any(AccountCreateChainType.self),
                selectable: any(Bool.self)
            ).then { sourceSelectionEnabled = $0.2 }
            stub.show(chainType: any(AccountCreateChainType.self)).thenDoNothing()
        }
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
        presenter.view = view

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
        XCTAssertEqual(sourceSelectionEnabled, false)
    }

    func testBitcoinTestnetMetadataDoesNotAdvertiseUnsupportedRawSeedImport() {
        let wallet = AccountGenerator.generateMetaAccount()
        let bitcoinTestnetChain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: UniversalWalletRegistry.bitcoinTestnet.chainId,
            parentId: nil,
            paraId: nil,
            name: UniversalWalletRegistry.bitcoinTestnet.name,
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        let view = MockAccountImportViewProtocol()
        var sourceSelectionEnabled: Bool?
        stub(view) { stub in
            stub.setSource(viewModel: any(InputViewModelProtocol.self)).thenDoNothing()
            stub.setName(
                viewModel: any(InputViewModelProtocol.self),
                visible: any(Bool.self)
            ).thenDoNothing()
            stub.setSource(
                type: any(AccountImportSource.self),
                chainType: any(AccountCreateChainType.self),
                selectable: any(Bool.self)
            ).then { sourceSelectionEnabled = $0.2 }
            stub.show(chainType: any(AccountCreateChainType.self)).thenDoNothing()
        }
        let presenter = AccountImportPresenter(
            wireframe: MockAccountImportWireframeProtocol(),
            interactor: MockAccountImportInteractorInputProtocol(),
            flow: .chain(
                model: UniqueChainModel(
                    meta: wallet,
                    chain: bitcoinTestnetChain
                )
            )
        )
        presenter.view = view

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
        XCTAssertEqual(sourceSelectionEnabled, false)
    }

    /// The Solana setup's "Enter wallet recovery phrase" opens the import for Solana: the
    /// wallet's own phrase restores the entire wallet, so no raw seed, JSON, derivation path or
    /// crypto type is offered (each would end at `unsupportedNetwork`).
    func testSolanaRootRecoveryAllowsOnlyWalletMnemonicForTheEntireWallet() {
        let wallet = AccountGenerator.generateMetaAccount()
        let view = MockAccountImportViewProtocol()
        let interactor = MockAccountImportInteractorInputProtocol()
        var sourceSelectionEnabled: Bool?
        var shownChainType: AccountCreateChainType?
        var uniqueChain: UniqueChainViewModel?
        stub(view) { stub in
            stub.setSource(viewModel: any(InputViewModelProtocol.self)).thenDoNothing()
            stub.setName(
                viewModel: any(InputViewModelProtocol.self),
                visible: any(Bool.self)
            ).thenDoNothing()
            stub.setSource(
                type: any(AccountImportSource.self),
                chainType: any(AccountCreateChainType.self),
                selectable: any(Bool.self)
            ).then { sourceSelectionEnabled = $0.2 }
            stub.show(chainType: any(AccountCreateChainType.self)).then { shownChainType = $0 }
            stub.setUniqueChain(viewModel: any(UniqueChainViewModel.self)).then { uniqueChain = $0 }
        }
        stub(interactor) { stub in
            stub.setup().thenDoNothing()
        }
        let presenter = AccountImportPresenter(
            wireframe: MockAccountImportWireframeProtocol(),
            interactor: interactor,
            flow: .chain(
                model: UniqueChainModel(
                    meta: wallet,
                    chain: UniversalWalletRegistry.solanaMainnetChainModel
                )
            )
        )
        presenter.view = view

        presenter.setup()
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
        XCTAssertEqual(presenter.selectedSourceType, .mnemonic)
        XCTAssertEqual(presenter.selectedCryptoType, .ed25519)
        XCTAssertEqual(sourceSelectionEnabled, false)
        XCTAssertEqual(shownChainType, .universal, "no Substrate derivation path or crypto type fields")
        XCTAssertEqual(
            uniqueChain?.text,
            R.string.localizable.universalImportEntireWallet(
                preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
            )
        )
        XCTAssertNotEqual(uniqueChain?.text, UniversalWalletRegistry.solanaMainnetChainModel.name)
        XCTAssertNil(uniqueChain?.icon)
    }

    func testNetworkIssueForSolanaOffersOnlyTheWalletPhraseImport() {
        for chain in [
            UniversalWalletRegistry.solanaMainnetChainModel,
            UniversalWalletRegistry.bitcoinMainnetChainModel,
            UniversalWalletRegistry.tairaChainModel
        ] {
            XCTAssertEqual(
                NetworkIssuesNotificationPresenter.missingAccountOptions(for: chain, unused: false),
                [.import, .skip],
                chain.name
            )
        }
        XCTAssertEqual(
            NetworkIssuesNotificationPresenter.missingAccountOptions(
                for: ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.kusamaChainId, prefix: 2),
                unused: true
            ),
            [.create, .import]
        )
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

    func testTairaRecoveryPhraseCreatesBothAccountsAndStoresOnlyRootEntropy() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let mnemonicString = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let wallet = try makeMnemonicWalletIdentity(mnemonicString: mnemonicString)
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
                for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
            )
        )
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: account.accountId
                )
            )
        )
        XCTAssertTrue(
            UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
                in: updatedWallet,
                for: UniversalWalletRegistry.bitcoinMainnet.chainId
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
        let tairaWallet = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: try makeMnemonicWalletIdentity(mnemonicString: mnemonicString),
            mnemonic: mnemonicString
        )
        let originalAccount = try XCTUnwrap(tairaWallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.isValidTairaAccount($0)
        }))
        let wallet = try makeMnemonicWalletIdentity(
            mnemonicString: mnemonicString,
            chainAccounts: [originalAccount]
        )
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
                for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
            )
        )
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: originalAccount.accountId
                )
            )
        )
    }

    func testTairaRecoveryRejectsPhraseThatDoesNotMatchWalletIdentity() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let originalMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let replacementMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let walletWithTaira = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: try makeMnemonicWalletIdentity(mnemonicString: originalMnemonic),
            mnemonic: originalMnemonic
        )
        let originalAccount = try XCTUnwrap(walletWithTaira.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.isValidTairaAccount($0)
        }))
        let wallet = try makeMnemonicWalletIdentity(
            mnemonicString: originalMnemonic,
            chainAccounts: [originalAccount]
        )
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
            XCTAssertEqual(
                error as? UniversalWalletRootRecoveryError,
                .phraseDoesNotMatchWallet
            )
        }
        XCTAssertEqual(try keychain.fetchKey(for: entropyTag), existingEntropy)
        XCTAssertEqual(
            wallet.chainAccounts.first(where: {
                UniversalWalletChainAccountSupport.isValidTairaAccount($0)
            }),
            originalAccount
        )
        XCTAssertFalse(
            try keychain.checkKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
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

    func testBitcoinRecoveryPhraseCreatesBothAccountsAndStoresOnlyRootEntropy() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let mnemonicString = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let wallet = try makeMnemonicWalletIdentity(mnemonicString: mnemonicString)
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
                for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
            )
        )
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: account.accountId
                )
            )
        )
        XCTAssertTrue(
            UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
                in: updatedWallet,
                for: UniversalWalletRegistry.taira.chainId
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

    func testBitcoinRawSeedImportIsRejectedToProtectSinglePhraseRecovery() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let wallet = AccountGenerator.generateMetaAccount()
        let walletSeed = Data(repeating: 0, count: UniversalWalletSeedBridge.walletSeedLength)
        let request = ChainAccountImportSeedRequest(
            seed: walletSeed.toHex(includePrefix: false),
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
            guard case AccountOperationFactoryError.unsupportedNetwork = error else {
                return XCTFail("Expected chain-specific Bitcoin seed import to fail, got \(error)")
            }
        }
        XCTAssertTrue(wallet.chainAccounts.isEmpty)
        XCTAssertFalse(
            try keychain.checkKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        )
    }

    func testBitcoinRawSeedImportFailsBeforeParsingOrKeychainWrite() throws {
        let keychain = MockKeystoreProtocol()
        stub(keychain) { stub in
            stub.checkKey(for: any()).thenReturn(false)
            stub.addKey(any(), with: any()).thenDoNothing()
            stub.updateKey(any(), with: any()).thenDoNothing()
        }
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let wallet = AccountGenerator.generateMetaAccount()
        let invalidLengths = [
            UniversalWalletSeedBridge.walletSeedLength - 1,
            UniversalWalletSeedBridge.walletSeedLength + 1
        ]

        for invalidLength in invalidLengths {
            let request = ChainAccountImportSeedRequest(
                seed: Data(repeating: 0, count: invalidLength).toHex(includePrefix: false),
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
                guard case AccountOperationFactoryError.unsupportedNetwork = error else {
                    return XCTFail("Expected Bitcoin seed import to fail before parsing, got \(error)")
                }
            }
        }
        verify(keychain, times(0)).addKey(any(), with: any())
        verify(keychain, times(0)).updateKey(any(), with: any())
        XCTAssertTrue(wallet.chainAccounts.isEmpty)
    }

    func testBitcoinMnemonicImportRestoresSignerWithoutChangingExistingAddress() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let mnemonicString = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let bitcoinWallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: try makeMnemonicWalletIdentity(mnemonicString: mnemonicString),
            mnemonic: mnemonicString
        )
        let originalAccount = try XCTUnwrap(bitcoinWallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let wallet = try makeMnemonicWalletIdentity(
            mnemonicString: mnemonicString,
            chainAccounts: [originalAccount]
        )
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
                for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
            )
        )
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: originalAccount.accountId
                )
            )
        )
    }

    func testBitcoinRecoveryRejectsPhraseThatDoesNotMatchWalletIdentity() throws {
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let originalMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let replacementMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let walletWithBitcoin = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: try makeMnemonicWalletIdentity(mnemonicString: originalMnemonic),
            mnemonic: originalMnemonic
        )
        let originalAccount = try XCTUnwrap(walletWithBitcoin.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let wallet = try makeMnemonicWalletIdentity(
            mnemonicString: originalMnemonic,
            chainAccounts: [originalAccount]
        )
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
            XCTAssertEqual(
                error as? UniversalWalletRootRecoveryError,
                .phraseDoesNotMatchWallet
            )
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
        XCTAssertFalse(
            try keychain.checkKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        )
    }

    func testRootRecoveryPreservesExistingBitcoinFromDifferentPhrase() throws {
        let rootMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let legacyMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let rootWallet = try makeMnemonicWalletIdentity(mnemonicString: rootMnemonic)
        let legacyWallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: legacyMnemonic
        )
        let legacyAccount = try XCTUnwrap(legacyWallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let wallet = rootWallet.replacingChainAccounts([legacyAccount])
        let keychain = InMemoryKeychain()
        let legacyEntropyTag = KeystoreTagV2.entropyTagForMetaId(
            wallet.metaId,
            accountId: legacyAccount.accountId
        )
        let legacyEntropy = Data("legacy-chain-entropy".utf8)
        try keychain.saveKey(legacyEntropy, with: legacyEntropyTag)
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: rootMnemonic),
            username: wallet.name,
            derivationPath: "",
            cryptoType: .ecdsa,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId
        )

        let operation = MetaAccountOperationFactory(keystore: keychain)
            .importChainAccountOperation(request: request)
        operation.start()

        XCTAssertThrowsError(
            try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletRootRecoveryError,
                .existingAccountUsesDifferentPhrase
            )
        }
        XCTAssertEqual(try keychain.fetchKey(for: legacyEntropyTag), legacyEntropy)
        XCTAssertFalse(
            try keychain.checkKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        )
        XCTAssertEqual(wallet.chainAccounts, [legacyAccount])
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

    func testUniversalRootRecoveryRollsBackEntropyWhenWalletPersistenceFails() throws {
        let mnemonicString = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        let wallet = try makeMnemonicWalletIdentity(mnemonicString: mnemonicString)
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: wallet.name,
            derivationPath: "",
            cryptoType: .ecdsa,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId
        )
        let storageFacade = AlwaysFailingAccountImportStorageFacade()
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        let repository = AccountRepositoryFactory(storageFacade: storageFacade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        let interactor = AccountImportInteractor(
            accountOperationFactory: operationFactory,
            accountRepository: AnyDataProviderRepository(repository),
            operationManager: OperationManager(),
            settings: settings,
            keystoreImportService: KeystoreImportService(logger: Logger.shared),
            eventCenter: MockEventCenterProtocol(),
            defaultSource: .mnemonic
        )
        let presenter = MockAccountImportInteractorOutputProtocol()
        interactor.presenter = presenter
        let failure = expectation(description: "Wallet persistence failure delivered")
        failure.assertForOverFulfill = true

        stub(presenter) { stub in
            when(stub.didReceiveAccountImport(error: any(Error.self))).then { _ in
                failure.fulfill()
            }
            when(stub.didCompleteAccountImport()).then {
                XCTFail("Persistence failure must not complete recovery")
            }
        }

        let operation = operationFactory.importChainAccountOperation(request: request)
        interactor.importAccountUsingOperation(operation)

        wait(for: [failure], timeout: 10)
        XCTAssertNil(settings.value)
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
            )
        )
    }

    func testReimportingStoredUnusedNetworkAccountMakesItTheAccountInUse() throws {
        // IK-11: a save never makes a stored alternative the account in use, but importing
        // that same account for its network is the user's explicit choice to use it.
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let storageFacade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(storageFacade: storageFacade, operationQueue: OperationQueue())
        let polkadot = ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.polkadotChainId)
        let olderSeed = "0x" + String(repeating: "3c", count: 32)

        let walletOperation = operationFactory.newMetaAccountOperation(
            request: MetaAccountImportMnemonicRequest(
                mnemonic: try IRMnemonicCreator().mnemonic(
                    fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
                ),
                username: "Main", substrateDerivationPath: "",
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: .sr25519, defaultChainId: nil
            ),
            isBackuped: true
        )
        OperationQueue().addOperations([walletOperation], waitUntilFinished: true)
        let wallet = try walletOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        try ChainAccountRecordsFixture.save(wallet, in: storageFacade)

        // The older Polkadot account as the 4.0.x releases left it: stored but not in use.
        let olderOperation = operationFactory.importChainAccountOperation(request: ChainAccountImportSeedRequest(
            seed: olderSeed, username: wallet.name, derivationPath: "", cryptoType: .sr25519,
            isEthereum: false, meta: wallet, chainId: polkadot.chainId
        ))
        OperationQueue().addOperations([olderOperation], waitUntilFinished: true)
        let olderAccount = try XCTUnwrap(
            try olderOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .chainAccounts.first { $0.chainId == polkadot.chainId }
        )
        try ChainAccountRecordsFixture.insertHiddenRow(olderAccount, in: wallet.metaId, facade: storageFacade)
        XCTAssertEqual(
            try ChainAccountRecordsFixture.wallets(in: storageFacade).first?
                .fetch(for: polkadot.accountRequest())?.accountId,
            wallet.substrateAccountId
        )

        let eventCenter = MockEventCenterProtocol()
        stub(eventCenter) { stub in
            when(stub.notify(with: any())).thenDoNothing()
        }
        let interactor = AccountImportInteractor(
            accountOperationFactory: operationFactory,
            accountRepository: AnyDataProviderRepository(
                AccountRepositoryFactory(storageFacade: storageFacade).createMetaAccountRepository(
                    for: nil, sortDescriptors: []
                )
            ),
            operationManager: OperationManager(),
            settings: settings,
            keystoreImportService: KeystoreImportService(logger: Logger.shared),
            eventCenter: eventCenter,
            defaultSource: .seed,
            walletRecordsInspector: StoredWalletRecordsInspector(storageFacade: storageFacade)
        )
        let presenter = MockAccountImportInteractorOutputProtocol()
        interactor.presenter = presenter
        let completed = expectation(description: "Per-chain import completes")
        stub(presenter) { stub in
            when(stub.didCompleteAccountImport()).then { completed.fulfill() }
            when(stub.didReceiveAccountImport(error: any())).then { error in
                XCTFail("Unexpected import error: \(error)")
            }
        }

        interactor.importUniqueChain(request: UniqueChainImportRequest(
            source: .seed(data: .init(seed: olderSeed, derivationPath: "")),
            username: wallet.name,
            cryptoType: .sr25519,
            meta: wallet,
            chain: polkadot
        ))
        wait(for: [completed], timeout: 10)

        XCTAssertEqual(settings.value?.fetch(for: polkadot.accountRequest())?.accountId, olderAccount.accountId)
        XCTAssertEqual(
            try ChainAccountRecordsFixture.wallets(in: storageFacade).first?
                .fetch(for: polkadot.accountRequest())?.accountId,
            olderAccount.accountId
        )
        XCTAssertEqual(
            try ChainAccountRecordsFixture.projections(in: storageFacade).first?.chainAccountRecords?.alternatives,
            []
        )
        verify(eventCenter).notify(with: any())
    }

    @MainActor
    func testHeldPerChainImportDoesNotReselectWalletAfterNewerSelection() async throws {
        try await heldPerChainImportNewerSelection(afterInspection: false)
    }

    @MainActor
    func testHeldPerChainFollowupDoesNotReselectAfterInspectorCompletes() async throws {
        try await heldPerChainImportNewerSelection(afterInspection: true)
    }

    @MainActor
    func testHeldPerChainFollowupPreservesNewerMetadataEdit() async throws {
        try await heldPerChainImportNewerSelection(afterInspection: true, rename: true)
    }

    @MainActor
    private func heldPerChainImportNewerSelection(afterInspection: Bool, rename: Bool = false) async throws {
        // IK-11: a save never makes a stored alternative the account in use, but importing
        // that same account for its network is the user's explicit choice to use it.
        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let storageFacade = UserDataStorageTestFacade()
        let settingsQueue = OperationQueue()
        let settings = SelectedWalletSettings(storageFacade: storageFacade, operationQueue: settingsQueue)
        let polkadot = ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.polkadotChainId)
        let olderSeed = "0x" + String(repeating: "3c", count: 32)

        let walletOperation = operationFactory.newMetaAccountOperation(
            request: MetaAccountImportMnemonicRequest(
                mnemonic: try IRMnemonicCreator().mnemonic(
                    fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
                ),
                username: "Main", substrateDerivationPath: "",
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: .sr25519, defaultChainId: nil
            ),
            isBackuped: true
        )
        OperationQueue().addOperations([walletOperation], waitUntilFinished: true)
        let wallet = try walletOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        try ChainAccountRecordsFixture.save(wallet, in: storageFacade)

        // The older Polkadot account as the 4.0.x releases left it: stored but not in use.
        let olderOperation = operationFactory.importChainAccountOperation(request: ChainAccountImportSeedRequest(
            seed: olderSeed, username: wallet.name, derivationPath: "", cryptoType: .sr25519,
            isEthereum: false, meta: wallet, chainId: polkadot.chainId
        ))
        OperationQueue().addOperations([olderOperation], waitUntilFinished: true)
        let olderAccount = try XCTUnwrap(
            try olderOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .chainAccounts.first { $0.chainId == polkadot.chainId }
        )
        try ChainAccountRecordsFixture.insertHiddenRow(olderAccount, in: wallet.metaId, facade: storageFacade)
        XCTAssertEqual(
            try ChainAccountRecordsFixture.wallets(in: storageFacade).first?
                .fetch(for: polkadot.accountRequest())?.accountId,
            wallet.substrateAccountId
        )

        let secondOperation = try nativeTonRecoveryOperation(keychain)
        OperationQueue().addOperations([secondOperation], waitUntilFinished: true)
        let second = try secondOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let initialized = expectation(description: "Both wallets durably stored with first selected")
        settings.save(value: second, runningCompletionIn: .main) { result in
            if case .failure(let error) = result { XCTFail("Unexpected fixture persistence error: \(error)") }
        }
        settings.save(value: wallet, runningCompletionIn: .main) { result in
            if case .failure(let error) = result { XCTFail("Unexpected fixture persistence error: \(error)") }
            initialized.fulfill()
        }
        await fulfillment(of: [initialized], timeout: 10)
        (secondOperation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        XCTAssertEqual(settings.value?.metaId, wallet.metaId)
        XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: storageFacade).count, 2)
        let protectedOriginalRoot = try keychain.fetchKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId))
        let protectedSecondPhrase = try keychain.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(second.metaId))
        let eventCenter = MockEventCenterProtocol()
        var announcedSelections: [MetaAccountModel] = []
        stub(eventCenter) { stub in
            when(stub.notify(with: any())).then { event in
                if let selected = event as? SelectedAccountChanged { announcedSelections.append(selected.account) }
            }
        }
        let inspector = HeldActualImportInspector(storageFacade: storageFacade, hold: afterInspection)
        defer { inspector.release() }
        let interactor = AccountImportInteractor(
            accountOperationFactory: operationFactory,
            accountRepository: AnyDataProviderRepository(
                AccountRepositoryFactory(storageFacade: storageFacade).createMetaAccountRepository(
                    for: nil, sortDescriptors: []
                )
            ),
            operationManager: OperationManager(),
            settings: settings,
            keystoreImportService: KeystoreImportService(logger: Logger.shared),
            eventCenter: eventCenter,
            defaultSource: .seed,
            walletRecordsInspector: inspector
        )
        let presenter = MockAccountImportInteractorOutputProtocol()
        interactor.presenter = presenter
        let completed = expectation(description: "Per-chain import completes")
        stub(presenter) { stub in
            when(stub.didCompleteAccountImport()).then { completed.fulfill() }
            when(stub.didReceiveAccountImport(error: any())).then { error in
                XCTFail("Unexpected import error: \(error)")
            }
        }

        settingsQueue.isSuspended = true
        defer { settingsQueue.isSuspended = false; withExtendedLifetime((interactor, presenter, secondOperation)) {} }
        interactor.importUniqueChain(request: UniqueChainImportRequest(
            source: .seed(data: .init(seed: olderSeed, derivationPath: "")),
            username: wallet.name,
            cryptoType: .sr25519,
            meta: wallet,
            chain: polkadot
        ))
        await tonWait { settingsQueue.operationCount > 0 }
        if afterInspection {
            settingsQueue.isSuspended = false
            await tonWait { inspector.hasReachedHold }
            XCTAssertTrue(inspector.hasReachedHold)
        }
        let newerSelection = rename ? try XCTUnwrap(settings.value).replacingName("Newer preserved name") : second
        let selectedSecond = expectation(description: "Newer selected wallet acknowledged")
        settings.save(value: newerSelection, runningCompletionIn: .main) { result in
            if case .failure(let error) = result { XCTFail("Unexpected newer selection failure: \(error)") }
            selectedSecond.fulfill()
        }
        XCTAssertEqual(settings.value?.metaId, newerSelection.metaId)
        settingsQueue.isSuspended = false
        if afterInspection {
            await fulfillment(of: [selectedSecond], timeout: 10)
            inspector.release()
            await fulfillment(of: [completed], timeout: 10)
        } else {
            await fulfillment(of: [completed, selectedSecond], timeout: 10)
        }
        var settled = false
        settings.performAfterPendingSaves { DispatchQueue.main.async { settled = true } }
        await tonWait { settled }
        XCTAssertEqual(settings.value?.metaId, newerSelection.metaId, "Optional import follow-up must not reselect an older wallet")
        XCTAssertEqual(settings.value?.name, newerSelection.name)
        let projections = try ChainAccountRecordsFixture.projections(in: storageFacade)
        XCTAssertEqual(projections.filter(\.isSelected).map(\.identifier), [newerSelection.metaId])
        XCTAssertEqual(projections.first { $0.identifier == newerSelection.metaId }?.wallet?.name, newerSelection.name)
        XCTAssertFalse(announcedSelections.contains { $0.metaId == wallet.metaId && $0.name == wallet.name },
                       "Do not publish the old import snapshot after newer selection or metadata")
        XCTAssertEqual(try keychain.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(second.metaId)), protectedSecondPhrase)
        XCTAssertNotNil(projections.first { $0.identifier == wallet.metaId }?.wallet)
        XCTAssertEqual(try keychain.fetchKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)), protectedOriginalRoot)
    }

    @MainActor
    func testMnemonicRestore() throws {
        // given
        let owner = UIViewController()
        let (window, _) = try tonHost(owner)
        defer { window.isHidden = true; window.rootViewController = nil }

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
            when(stub.controller.get).thenReturn(owner)
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

        _ = sourceInputViewModel?.inputHandler.didReceiveReplacement(
            expectedMnemonic,
            for: NSRange(location: 0, length: 0)
        )

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

private final class AlwaysFailingAccountImportCoreDataService: CoreDataServiceProtocol {
    let configuration: CoreDataServiceConfigurationProtocol

    init(configuration: CoreDataServiceConfigurationProtocol) {
        self.configuration = configuration
    }

    func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        block(
            nil,
            NSError(
                domain: "AccountImportPersistenceFailure",
                code: 1
            )
        )
    }

    func close() throws {}
    func drop() throws {}
}

private final class AlwaysFailingAccountImportStorageFacade: StorageFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init() {
        let configuration = UserDataStorageTestFacade().databaseService.configuration
        databaseService = AlwaysFailingAccountImportCoreDataService(
            configuration: configuration
        )
    }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
        CoreDataRepository(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }

    func createAsyncRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> AsyncCoreDataRepositoryDefault<T, U> where T: Identifiable, U: NSManagedObject {
        AsyncCoreDataRepositoryDefault(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}

private final class HeldActualImportInspector: StoredWalletRecordsInspecting {
    private let actual: StoredWalletRecordsInspector
    private let condition = NSCondition()
    private let hold: Bool
    private var reached = false
    private var released = false
    var hasReachedHold: Bool { condition.lock(); defer { condition.unlock() }; return reached }
    init(storageFacade: StorageFacadeProtocol, hold: Bool) {
        actual = StoredWalletRecordsInspector(storageFacade: storageFacade)
        self.hold = hold
    }
    func release() { condition.lock(); released = true; condition.broadcast(); condition.unlock() }
    func fetchReportOperation() -> BaseOperation<StoredWalletRecordsReport> { actual.fetchReportOperation() }
    func selectChainAccountOperation(_ update: ChainAccountSelectionUpdate, walletId: MetaAccountId)
        -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let operation = self.actual.selectChainAccountOperation(update, walletId: walletId)
            operation.start()
            let value = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            if self.hold {
                self.condition.lock()
                defer { self.condition.unlock() }
                self.reached = true
                let deadline = Date().addingTimeInterval(15)
                while !self.released {
                    guard self.condition.wait(until: deadline) else {
                        throw NSError(domain: "HeldInspectorTimedOut", code: 1)
                    }
                }
            }
            return value
        }
    }
}

private final class ControllableImportCoreDataService: CoreDataServiceProtocol {
    let underlying: CoreDataServiceProtocol
    private let lock = NSLock()
    private var shouldFail = false
    var failureEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return shouldFail }
        set { lock.lock(); shouldFail = newValue; lock.unlock() }
    }
    var configuration: CoreDataServiceConfigurationProtocol { underlying.configuration }
    init(_ underlying: CoreDataServiceProtocol) { self.underlying = underlying }
    func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        if failureEnabled {
            block(nil, NSError(domain: "HeldImportPersistenceFailure", code: 1))
        } else {
            underlying.performAsync(block: block)
        }
    }
    func close() throws { try underlying.close() }
    func drop() throws { try underlying.drop() }
}

private final class ControllableImportStorageFacade: StorageFacadeProtocol {
    let service: ControllableImportCoreDataService
    var databaseService: CoreDataServiceProtocol { service }
    init(_ underlying: StorageFacadeProtocol) { service = ControllableImportCoreDataService(underlying.databaseService) }
    func createRepository<T, U>(filter: NSPredicate?, sortDescriptors: [NSSortDescriptor],
                                mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
        where T: Identifiable, U: NSManagedObject {
        CoreDataRepository(databaseService: databaseService, mapper: mapper,
                           filter: filter, sortDescriptors: sortDescriptors)
    }
    func createAsyncRepository<T, U>(filter: NSPredicate?, sortDescriptors: [NSSortDescriptor],
                                     mapper: AnyCoreDataMapper<T, U>) -> AsyncCoreDataRepositoryDefault<T, U>
        where T: Identifiable, U: NSManagedObject {
        AsyncCoreDataRepositoryDefault(databaseService: databaseService, mapper: mapper,
                                       filter: filter, sortDescriptors: sortDescriptors)
    }
}

private final class NativeTonRecoveryTestKeychain: KeystoreProtocol {
    var values: [String: Data] = [:]
    var failOnAddNumber: Int?
    private var additions = 0
    func addKey(_ key: Data, with identifier: String) throws {
        additions += 1
        if additions == failOnAddNumber { throw KeystoreError.unexpectedFail }
        guard values[identifier] == nil else { throw KeystoreError.duplicatedItem }
        values[identifier] = key
    }
    func updateKey(_: Data, with _: String) throws { throw KeystoreError.unexpectedFail }
    func fetchKey(for identifier: String) throws -> Data {
        guard let key = values[identifier] else { throw KeystoreError.noKeyFound }
        return key
    }
    func checkKey(for identifier: String) throws -> Bool { values[identifier] != nil }
    func deleteKey(for identifier: String) throws { values.removeValue(forKey: identifier) }
}

@MainActor
extension AccountImportTests {
    private func tonHost(_ controller: UIViewController, large: Bool = false) throws -> (UIWindow, UINavigationController) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = large ? .accessibilityExtraExtraExtraLarge : .large
        }
        let navigation = FearlessNavigationController(rootViewController: UIViewController())
        navigation.setViewControllers([navigation.viewControllers[0], controller], animated: false)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return (window, navigation)
    }

    private func tonWait(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(condition(), "TON import UI did not settle")
    }

    private func tonDescendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(tonDescendants)
    }

    private func tonCapture(_ window: UIWindow, _ name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["TON_IMPORT_EVIDENCE_DIR"] else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try XCTUnwrap(image.pngData()).write(to: url.appendingPathComponent(name + ".png"))
    }

    private func tonActivate(_ control: UIControl, window: UIWindow, capture: String? = nil) async throws {
        var parent = control.superview
        while let current = parent {
            if let scroll = current as? UIScrollView {
                scroll.scrollRectToVisible(control.convert(control.bounds, to: scroll).insetBy(dx: 0, dy: -8), animated: false)
            }
            parent = current.superview
        }
        window.layoutIfNeeded()
        await tonWait {
            let point = control.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), to: window)
            let hit = window.hitTest(point, with: nil)
            return hit === control || hit?.isDescendant(of: control) == true
        }
        if let button = control as? TriangularedButton, let label = button.wrappingLabel {
            let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            XCTAssertLessThanOrEqual(needed.height, label.bounds.height + 1, "Whole address/action text must fit")
        }
        if let capture { try tonCapture(window, capture) }
        control.sendActions(for: .touchUpInside)
    }

    func testActualNativeTonAddressControlsPreserveChosenIdentityAndBytes() async throws {
        let previousLocale = LocalizationManager.shared.selectedLocalization
        defer { LocalizationManager.shared.selectedLocalization = previousLocale }
        for language in ["en", "ru", "zh-Hans"] {
            LocalizationManager.shared.selectedLocalization = language
            for normalized in [false, true] {
                let owner = UIViewController()
                let (window, _) = try tonHost(owner, large: true)
                let coordinator = NativeTonImportCoordinator()
                defer { coordinator.cancel(); window.isHidden = true; window.rootViewController = nil }
                let old = historicalTypedTonRecoveryCases[0]
                var received: [LegacyTonMnemonic] = []
                coordinator.start(phrase: old.phrase, locale: Locale(identifier: language), from: owner,
                                  isCurrent: { true }) { result in
                    do { received.append(try result.get()) } catch { XCTFail("\(error)") }
                }
                await tonWait { owner.presentedViewController?.viewIfLoaded?.window != nil && owner.presentedViewController?.isBeingPresented == false && owner.presentedViewController?.transitionCoordinator == nil }
                let sheet = try XCTUnwrap(owner.presentedViewController as? SheetAletViewController)
                try tonCapture(window, "instructions-\(language)-AX5-\(normalized)")
                XCTAssertTrue(received.isEmpty, "No import before the user chooses")
                XCTAssertTrue(coordinator.isPending)
                let identifier = normalized ? "ton-import-normalized" : "ton-import-as-typed"
                let button = try XCTUnwrap(tonDescendants(sheet.view).compactMap { $0 as? UIControl }.first { $0.accessibilityIdentifier == identifier })
                try await tonActivate(button, window: window, capture: "choose-\(language)-AX5-\(identifier)")
                button.sendActions(for: .touchUpInside)
                await tonWait { received.count == 1 && owner.presentedViewController == nil }
                XCTAssertFalse(coordinator.isPending)
                XCTAssertEqual(received.count, 1)
                let mnemonic = try XCTUnwrap(received.first)
                let expectedPhrase = normalized ? nativeTonRecoveryFixture : old.phrase
                let expectedPublicKey = normalized ? "34eb4b67d64f74d989ce2bc2e3dfddb7ed4cb0eec92f29fbecd05b1eabab0254" : old.publicKey
                XCTAssertEqual(mnemonic.toString(), expectedPhrase)
                XCTAssertEqual(mnemonic.importPublicKey?.toHex(includePrefix: false), expectedPublicKey)
                let keychain = NativeTonRecoveryTestKeychain()
                keychain.values["previous-wallet"] = Data([7, 9])
                let operation = MetaAccountOperationFactory(keystore: keychain).newMetaAccountOperation(request: MetaAccountImportMnemonicRequest(
                    mnemonic: mnemonic, username: "Recovered", substrateDerivationPath: "", ethereumDerivationPath: "",
                    cryptoType: .sr25519, defaultChainId: nil
                ), isBackuped: true)
                operation.start()
                let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                XCTAssertEqual(wallet.legacyTonAccount?.publicKey.toHex(includePrefix: false), expectedPublicKey)
                XCTAssertTrue((button as? TriangularedButton)?.imageWithTitleView?.title?.hasSuffix(try XCTUnwrap(wallet.legacyTonAccount).address) == true)
                XCTAssertEqual(try keychain.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)), Data(expectedPhrase.utf8))
                try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
                XCTAssertEqual(keychain.values, ["previous-wallet": Data([7, 9])])
            }
        }
    }

    func testNativeTonPendingDiscoveryRejectsDuplicateStaleAndBackgroundReplies() async throws {
        let owner = UIViewController(); let (window, _) = try tonHost(owner)
        defer { window.isHidden = true; window.rootViewController = nil }
        var replies: [(Result<[LegacyTonImportCandidate], Error>) -> Void] = []
        var operations: [Operation] = []
        let coordinator = NativeTonImportCoordinator { _, reply in
            replies.append(reply); let operation = Operation(); operations.append(operation); return operation
        }
        let candidates = try LegacyTonMnemonic.importCandidates(historicalTypedTonRecoveryCases[0].phrase)
        var current = true; var delivered = 0
        func begin() {
            coordinator.start(phrase: historicalTypedTonRecoveryCases[0].phrase, locale: Locale(identifier: "en"), from: owner,
                              isCurrent: { current }) { _ in delivered += 1 }
        }
        begin(); begin()
        XCTAssertEqual(replies.count, 1)
        current = false; replies[0](.success(candidates))
        await tonWait { !coordinator.isPending }
        XCTAssertNil(owner.presentedViewController)
        current = true; begin()
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertTrue(operations[1].isCancelled)
        replies[1](.success(candidates))
        begin() // A new attempt must not inherit the cancelled result.
        replies[1](.success(candidates))
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(owner.presentedViewController)
        XCTAssertTrue(coordinator.isPending)
        coordinator.cancel(); replies[2](.success(candidates))
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(delivered, 0)
        XCTAssertNil(owner.presentedViewController)
    }

    func testActualNativeTonCancelExternalDismissAndBackgroundPreventImport() async throws {
        for mode in ["cancel", "external", "background"] {
            let owner = UIViewController(); let (window, _) = try tonHost(owner)
            let coordinator = NativeTonImportCoordinator()
            defer { coordinator.cancel(); window.isHidden = true; window.rootViewController = nil }
            var delivered = 0
            coordinator.start(phrase: historicalTypedTonRecoveryCases[0].phrase, locale: Locale(identifier: "en"), from: owner,
                              isCurrent: { true }) { _ in delivered += 1 }
            await tonWait { owner.presentedViewController?.viewIfLoaded?.window != nil && owner.presentedViewController?.isBeingPresented == false && owner.presentedViewController?.transitionCoordinator == nil }
            let sheet = try XCTUnwrap(owner.presentedViewController as? SheetAletViewController)
            let stale = try XCTUnwrap(tonDescendants(sheet.view).compactMap { $0 as? UIControl }.first { $0.accessibilityIdentifier == "ton-import-as-typed" })
            if mode == "cancel" {
                try await tonActivate(sheet.rootView.closeButton, window: window, capture: "cancel-native-ton-choice")
                stale.sendActions(for: .touchUpInside) // Queued selection during the Cancel animation must be fenced.
            } else if mode == "external" {
                owner.dismiss(animated: false)
            } else {
                NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
            }
            await tonWait { owner.presentedViewController == nil && !coordinator.isPending }
            stale.sendActions(for: .touchUpInside)
            try? await Task.sleep(nanoseconds: 100_000_000)
            XCTAssertEqual(delivered, 0, mode)
        }
    }

    func testActualImportBackCancelsHeldNativeDiscovery() async throws {
        var reply: ((Result<[LegacyTonImportCandidate], Error>) -> Void)?
        let operation = Operation()
        let coordinator = NativeTonImportCoordinator { _, callback in reply = callback; return operation }
        let interactor = MockAccountImportInteractorInputProtocol()
        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.importMetaAccount(request: any())).then { _ in XCTFail("Abandoned import persisted") }
        }
        let presenter = AccountImportPresenter(wireframe: MockAccountImportWireframeProtocol(), interactor: interactor,
                                               flow: .wallet(step: .substrate), nativeTonImport: coordinator)
        let controller = AccountImportViewController(presenter: presenter); presenter.view = controller
        let (window, navigation) = try tonHost(controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        presenter.didReceiveAccountImport(metadata: MetaAccountImportMetadata(
            availableSources: AccountImportSource.allCases, defaultSource: .legacyTonMnemonic,
            availableCryptoTypes: CryptoType.allCases, defaultCryptoType: .sr25519
        ))
        presenter.sourceViewModel?.inputHandler.changeValue(to: historicalTypedTonRecoveryCases[0].phrase)
        presenter.usernameViewModel?.inputHandler.changeValue(to: "Abandoned")
        presenter.proceed()
        XCTAssertTrue(coordinator.isPending)
        await tonWait { controller.view.window != nil && controller.transitionCoordinator == nil }
        try? await Task.sleep(nanoseconds: 100_000_000)
        navigation.popViewController(animated: false)
        await tonWait { !coordinator.isPending }
        XCTAssertFalse(coordinator.isPending)
        XCTAssertTrue(operation.isCancelled)
        try XCTUnwrap(reply)(.success(LegacyTonMnemonic.importCandidates(historicalTypedTonRecoveryCases[0].phrase)))
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(navigation.presentedViewController)
        verify(interactor, never()).importMetaAccount(request: any())
    }
}

private final class ImportPersistenceRecordingWireframe: AccountImportWireframeProtocolStub, @unchecked Sendable {
    var navigations = 0
    var alerts = 0
    override func proceed(from view: AccountImportViewProtocol?, flow: AccountImportFlow) { navigations += 1 }
    override func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) { alerts += 1 }
    override func present(message: String?, title: String, closeAction: String?, from view: ControllerBackedProtocol?, actions: [SheetAlertPresentableAction]) { alerts += 1 }
    override func presentInfo(message: String?, title: String, from view: ControllerBackedProtocol?) { alerts += 1 }
}

@MainActor
extension AccountImportTests {
    func testActualImportBackDuringHeldSavePreservesCommittedKeysWithoutLateNavigation() async throws {
        try await heldImportSaveAfterDeparture(fails: false)
    }

    func testActualImportBackDuringHeldFailedSaveRollsBackWithoutLateAlert() async throws {
        try await heldImportSaveAfterDeparture(fails: true)
    }

    func testActualImportBackgroundDuringHeldSaveDoesNotNavigate() async throws {
        try await heldImportSaveAfterDeparture(fails: false, departure: "background")
    }

    func testActualImportBackgroundDuringHeldFailedSaveDoesNotPresentError() async throws {
        try await heldImportSaveAfterDeparture(fails: true, departure: "background")
    }

    func testActualOwnedImportWaitsForAcknowledgementThenNavigatesOnce() async throws {
        try await heldImportSaveAfterDeparture(fails: false, departure: "none")
    }

    func testActualImportBackgroundSuccessContinuesWithoutAnotherPersistence() async throws {
        try await heldImportSaveAfterDeparture(fails: false, departure: "background", resume: true)
    }

    func testActualImportForegroundBeforeAcknowledgementRequiresExplicitContinue() async throws {
        try await heldImportSaveAfterDeparture(fails: false, departure: "background", resume: true,
                                              resumeBeforeAcknowledgement: true)
    }

    func testActualImportFailedBackgroundSaveCanRetryAfterReturning() async throws {
        try await heldImportSaveAfterDeparture(fails: true, departure: "background", resume: true)
    }

    func testActualOwnedImportFailureCanRetryWithActualContinue() async throws {
        try await heldImportSaveAfterDeparture(fails: true, departure: "none", resume: true)
    }

    func testActualAddingWalletBackgroundSuccessContinuesWithoutAnotherPersistence() async throws {
        try await heldImportSaveAfterDeparture(fails: false, departure: "background", resume: true, adding: true)
    }

    func testActualAddingWalletBackgroundFailureCanRetry() async throws {
        try await heldImportSaveAfterDeparture(fails: true, departure: "background", resume: true, adding: true)
    }

    func testActualImportCoveredByNewerNavigationDoesNotNavigate() async throws {
        try await heldImportSaveAfterDeparture(fails: false, departure: "covered", resume: true)
    }

    func testActualImportReturnFromCoverBeforeAcknowledgementRequiresContinue() async throws {
        try await heldImportSaveAfterDeparture(fails: false, departure: "covered", resume: true,
                                              resumeBeforeAcknowledgement: true)
    }

    func testActualImportSupersededSelectionRequiresContinueWithoutReselecting() async throws {
        try await heldImportSaveAfterDeparture(fails: false, departure: "selection", resume: true)
    }

    func testActualAddingWalletSupersededSelectionRequiresContinueWithoutReselecting() async throws {
        try await heldImportSaveAfterDeparture(fails: false, departure: "selection", resume: true, adding: true)
    }

    private func heldImportSaveAfterDeparture(
        fails: Bool, departure: String = "back", resume: Bool = false,
        resumeBeforeAcknowledgement: Bool = false, adding: Bool = false
    ) async throws {
        let healthyStorage = UserDataStorageTestFacade()
        let storage = ControllableImportStorageFacade(healthyStorage)
        let settingsQueue = OperationQueue()
        settingsQueue.isSuspended = true
        defer { settingsQueue.isSuspended = false }
        var saveInvocations = 0
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: settingsQueue,
                                             savePreparationHook: { saveInvocations += 1 })
        let keys = NativeTonRecoveryTestKeychain()
        keys.values["preexisting-public-sentinel"] = Data([8, 7, 6])
        let factory = MetaAccountOperationFactory(keystore: keys)
        let events = MockEventCenterProtocol()
        stub(events) { stub in when(stub.notify(with: any())).thenDoNothing() }
        let interactor: BaseAccountImportInteractor
        if adding {
            interactor = AddAccount.AccountImportInteractor(
                accountOperationFactory: factory,
                accountRepository: AnyDataProviderRepository(AccountRepositoryFactory(storageFacade: storage)
                    .createMetaAccountRepository(for: nil, sortDescriptors: [])),
                operationManager: OperationManager(), settings: settings,
                keystoreImportService: KeystoreImportService(logger: Logger.shared), eventCenter: events,
                defaultSource: .legacyTonMnemonic
            )
        } else {
            interactor = AccountImportInteractor(
            accountOperationFactory: factory,
            accountRepository: AnyDataProviderRepository(AccountRepositoryFactory(storageFacade: storage)
                .createMetaAccountRepository(for: nil, sortDescriptors: [])),
            operationManager: OperationManager(), settings: settings,
            keystoreImportService: KeystoreImportService(logger: Logger.shared), eventCenter: events,
            defaultSource: .legacyTonMnemonic,
            walletRecordsInspector: StoredWalletRecordsInspector(storageFacade: storage)
            )
        }
        let wireframe = ImportPersistenceRecordingWireframe()
        let presenter = AccountImportPresenter(wireframe: wireframe, interactor: interactor,
            flow: .wallet(step: .substrate))
        let controller = AccountImportViewController(presenter: presenter)
        presenter.view = controller; interactor.presenter = presenter
        let (window, navigation) = try tonHost(controller)
        defer { window.isHidden = true; window.rootViewController = nil; withExtendedLifetime((controller, presenter, interactor)) {} }
        presenter.usernameViewModel?.inputHandler.changeValue(to: "Public held import")
        controller.rootView.usernameTextField.text = "Public held import"
        controller.rootView.usernameTextField.animatedInputField.sendActions(for: .editingChanged)
        controller.rootView.textView.text = nativeTonRecoveryFixture
        controller.textViewDidChange(controller.rootView.textView)
        XCTAssertTrue(controller.rootView.nextButton.isUserInteractionEnabled)
        XCTAssertTrue(controller.rootView.nextButton.isEnabled)
        try await tonActivate(controller.rootView.nextButton, window: window)
        await tonWait { settings.value != nil && settingsQueue.operationCount > 0 }
        let pendingWallet = try XCTUnwrap(settings.value)
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(pendingWallet.metaId)
        XCTAssertEqual(try keys.fetchKey(for: entropyTag), Data(nativeTonRecoveryFixture.utf8))
        XCTAssertEqual(wireframe.navigations, 0, "No navigation before durable acknowledgement")
        XCTAssertEqual(wireframe.alerts, 0)
        XCTAssertEqual(saveInvocations, 1)
        XCTAssertFalse(controller.rootView.textViewContainer.isUserInteractionEnabled)
        XCTAssertFalse(controller.rootView.nextButton.isEnabled)
        controller.rootView.nextButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saveInvocations, 1, "Queued duplicate action cannot issue another save")
        storage.service.failureEnabled = fails
        if departure == "back" {
            navigation.popViewController(animated: false)
            await tonWait { controller.view.window == nil }
        } else if departure == "background" {
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
            if resumeBeforeAcknowledgement {
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            }
        } else if departure == "covered" {
            let covering = UIViewController()
            navigation.pushViewController(covering, animated: false)
            window.layoutIfNeeded()
            await tonWait { covering.viewIfLoaded?.window != nil && controller.view.window == nil &&
                covering.transitionCoordinator == nil && navigation.topViewController === covering }
            XCTAssertNil(controller.view.window, "The owner must actually depart before the return is qualified")
            try tonCapture(window, "held-import-cover-before-ack")
            if resumeBeforeAcknowledgement {
                navigation.popViewController(animated: false)
                await tonWait { controller.view.window != nil && navigation.topViewController === controller }
            }
        } else if departure == "selection" {
            let newer = factory.newMetaAccountOperation(request: MetaAccountImportMnemonicRequest(
                mnemonic: try IRMnemonicCreator().mnemonic(fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk"),
                username: "Newer selected wallet", substrateDerivationPath: "",
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum, cryptoType: .sr25519,
                defaultChainId: nil), isBackuped: true)
            newer.start()
            let newerWallet = try newer.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            settings.save(value: newerWallet, runningCompletionIn: .main) { result in
                if case let .failure(error) = result { XCTFail("Newer selection failed: \(error)") }
            }
        }
        let expectedSaveInvocations = departure == "selection" ? 2 : 1
        var settled = false
        settings.performAfterPendingSaves { DispatchQueue.main.async { settled = true } }
        settingsQueue.isSuspended = false
        await tonWait { settled }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(keys.values["preexisting-public-sentinel"], Data([8, 7, 6]))
        if fails {
            XCTAssertNil(settings.value)
            XCTAssertFalse(try keys.checkKey(for: entropyTag), "Failed durable write must roll back staged keys")
        } else {
            let stored = try XCTUnwrap(ChainAccountRecordsFixture.wallets(in: healthyStorage).first { $0.metaId == pendingWallet.metaId })
            XCTAssertEqual(stored.legacyTonAccount?.publicKey, pendingWallet.legacyTonAccount?.publicKey)
            XCTAssertEqual(try keys.fetchKey(for: entropyTag), Data(nativeTonRecoveryFixture.utf8))
        }
        XCTAssertEqual(wireframe.navigations, departure == "none" && !fails ? 1 : 0,
                       "Only the active import owner may navigate after acknowledgement")
        if departure != "none" {
            XCTAssertEqual(wireframe.alerts, 0, "A departed presenter must not show a late storage error")
            XCTAssertNil(controller.presentedViewController, "A background/departed import must not present a late error sheet")
        }
        if departure == "back" {
            controller.rootView.nextButton.sendActions(for: .touchUpInside)
            XCTAssertEqual(saveInvocations, 1, "Detached controls cannot retry or replace a committed wallet")
            XCTAssertEqual(wireframe.navigations, 0)
        }
        if resume {
            if departure == "background" {
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            } else if departure == "covered", navigation.topViewController !== controller {
                navigation.popViewController(animated: false)
                await tonWait { controller.view.window != nil && navigation.topViewController === controller }
            }
            if fails && departure == "none" {
                await tonWait { controller.presentedViewController?.viewIfLoaded?.window != nil &&
                    controller.presentedViewController?.transitionCoordinator == nil }
                let errorSheet = try XCTUnwrap(controller.presentedViewController as? SheetAletViewController)
                try await tonActivate(errorSheet.rootView.closeButton, window: window)
                await tonWait { controller.presentedViewController == nil }
            }
            XCTAssertEqual(wireframe.navigations, 0)
            let keysBeforeContinue = keys.values
            let selectionBeforeContinue = settings.value
            if departure == "selection" {
                XCTAssertEqual(selectionBeforeContinue?.name, "Newer selected wallet")
                XCTAssertNotEqual(selectionBeforeContinue?.metaId, pendingWallet.metaId)
            }
            if fails {
                XCTAssertTrue(controller.rootView.textViewContainer.isUserInteractionEnabled)
                storage.service.failureEnabled = false
                settingsQueue.isSuspended = true
            } else {
                XCTAssertFalse(controller.rootView.textViewContainer.isUserInteractionEnabled,
                               "Committed phrase cannot be edited to imply a different retry")
            }
            try await tonActivate(controller.rootView.nextButton, window: window,
                                  capture: "held-import-continue-\(adding)-\(departure)-\(fails)")
            if fails {
                await tonWait { saveInvocations == 2 && settingsQueue.operationCount > 0 }
                XCTAssertEqual(wireframe.navigations, 0)
                settingsQueue.isSuspended = false
                await tonWait { wireframe.navigations == 1 }
                let retried = try XCTUnwrap(settings.value)
                XCTAssertEqual(try keys.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(retried.metaId)),
                               Data(nativeTonRecoveryFixture.utf8))
                XCTAssertFalse(try keys.checkKey(for: entropyTag))
                XCTAssertEqual(saveInvocations, 2)
            } else {
                XCTAssertEqual(keys.values, keysBeforeContinue)
                XCTAssertEqual(saveInvocations, expectedSaveInvocations, "Continue after acknowledgement never reimports")
                XCTAssertEqual(settings.value, selectionBeforeContinue)
                XCTAssertEqual(wireframe.navigations, 1)
            }
            XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: healthyStorage).count,
                           departure == "selection" ? 2 : 1)
            controller.rootView.nextButton.sendActions(for: .touchUpInside)
            presenter.didCompleteAccountImport() // Duplicate completion cannot navigate twice.
            XCTAssertEqual(wireframe.navigations, 1)
            XCTAssertEqual(saveInvocations, fails ? 2 : expectedSaveInvocations)
        }
    }
}

@MainActor
extension AccountImportTests {
    func testDeallocatedImportOwnerStillCommitsAcknowledgedKeys() async throws {
        try await deallocatedImportOwner(adding: false, fails: false)
    }

    func testDeallocatedImportOwnerStillRollsBackFailedKeys() async throws {
        try await deallocatedImportOwner(adding: false, fails: true)
    }

    func testDeallocatedAddAccountOwnerStillCommitsAcknowledgedKeys() async throws {
        try await deallocatedImportOwner(adding: true, fails: false)
    }

    func testDeallocatedAddAccountOwnerStillRollsBackFailedKeys() async throws {
        try await deallocatedImportOwner(adding: true, fails: true)
    }

    private func deallocatedImportOwner(adding: Bool, fails: Bool) async throws {
        let healthyStorage = UserDataStorageTestFacade()
        let storage = ControllableImportStorageFacade(healthyStorage)
        let queue = OperationQueue()
        queue.isSuspended = true
        defer { queue.isSuspended = false }
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: queue)
        let keys = NativeTonRecoveryTestKeychain()
        keys.values["preserved-before-import"] = Data([2, 6, 9])
        let factory = MetaAccountOperationFactory(keystore: keys)
        let events = MockEventCenterProtocol()
        stub(events) { stub in when(stub.notify(with: any())).thenDoNothing() }
        let repository = AnyDataProviderRepository(AccountRepositoryFactory(storageFacade: storage)
            .createMetaAccountRepository(for: nil, sortDescriptors: []))
        var interactor: BaseAccountImportInteractor?
        if adding {
            interactor = AddAccount.AccountImportInteractor(
                accountOperationFactory: factory, accountRepository: repository,
                operationManager: OperationManager(), settings: settings,
                keystoreImportService: KeystoreImportService(logger: Logger.shared),
                eventCenter: events, defaultSource: .legacyTonMnemonic
            )
        } else {
            interactor = AccountImportInteractor(
                accountOperationFactory: factory, accountRepository: repository,
                operationManager: OperationManager(), settings: settings,
                keystoreImportService: KeystoreImportService(logger: Logger.shared),
                eventCenter: events, defaultSource: .legacyTonMnemonic,
                walletRecordsInspector: StoredWalletRecordsInspector(storageFacade: storage)
            )
        }
        weak var oldInteractor = interactor
        let output = MockAccountImportInteractorOutputProtocol()
        stub(output) { stub in
            when(stub.didCompleteAccountImport()).then { XCTFail("Released owner completed UI") }
            when(stub.didReceiveAccountImport(error: any())).then { _ in XCTFail("Released owner presented error") }
        }
        interactor?.presenter = output
        interactor?.importMetaAccount(request: MetaAccountImportRequest(
            source: .mnemonic(data: .init(mnemonic: try LegacyTonMnemonic.validatedForImport(nativeTonRecoveryFixture),
                substrateDerivationPath: "", ethereumDerivationPath: "")),
            username: "Released public owner", cryptoType: .sr25519, defaultChainId: nil
        ))
        await tonWait { settings.value != nil && queue.operationCount > 0 }
        let pending = try XCTUnwrap(settings.value)
        let entropy = KeystoreTagV2.entropyTagForMetaId(pending.metaId)
        XCTAssertEqual(keys.values[entropy], Data(nativeTonRecoveryFixture.utf8))
        storage.service.failureEnabled = fails
        interactor = nil
        await tonWait { oldInteractor == nil }
        XCTAssertNil(oldInteractor)
        var settled = false
        settings.performAfterPendingSaves { DispatchQueue.main.async { settled = true } }
        queue.isSuspended = false
        await tonWait { settled }
        if fails {
            await tonWait { keys.values[entropy] == nil }
            XCTAssertNil(settings.value)
            XCTAssertEqual(keys.values, ["preserved-before-import": Data([2, 6, 9])])
            XCTAssertTrue(try ChainAccountRecordsFixture.wallets(in: healthyStorage).isEmpty)
        } else {
            XCTAssertEqual(keys.values[entropy], Data(nativeTonRecoveryFixture.utf8))
            let stored = try XCTUnwrap(ChainAccountRecordsFixture.wallets(in: healthyStorage).first)
            XCTAssertEqual(stored.metaId, pending.metaId)
            XCTAssertEqual(stored.legacyTonAccount?.publicKey, pending.legacyTonAccount?.publicKey)
            XCTAssertEqual(keys.values["preserved-before-import"], Data([2, 6, 9]))
        }
        verify(events, never()).notify(with: any())
    }
}

private final class GenericImportFaultKeychain: KeystoreProtocol {
    private let lock = NSRecursiveLock()
    private var stored: [String: Data] = [:]
    private var writes = 0
    var failDelete = false
    var failRead = false
    var failWrite: Int?
    var failAfterMutation = false
    var snapshot: [String: Data] {
        lock.lock(); defer { lock.unlock() }; return stored
    }
    func resetFault(at: Int?, afterMutation: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        writes = 0; failWrite = at; failAfterMutation = afterMutation
    }
    func addKey(_ key: Data, with identifier: String) throws {
        try write(key, identifier: identifier, mustExist: false)
    }
    func updateKey(_ key: Data, with identifier: String) throws {
        try write(key, identifier: identifier, mustExist: true)
    }
    private func write(_ key: Data, identifier: String, mustExist: Bool) throws {
        lock.lock(); defer { lock.unlock() }
        guard (stored[identifier] != nil) == mustExist else {
            throw mustExist ? KeystoreError.noKeyFound : KeystoreError.duplicatedItem
        }
        writes += 1
        if writes == failWrite && !failAfterMutation { throw KeystoreError.unexpectedFail }
        stored[identifier] = key
        if writes == failWrite { throw KeystoreError.unexpectedFail }
    }
    func fetchKey(for identifier: String) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        if failRead { throw KeystoreError.unexpectedFail }
        guard let value = stored[identifier] else { throw KeystoreError.noKeyFound }
        return value
    }
    func checkKey(for identifier: String) throws -> Bool {
        lock.lock(); defer { lock.unlock() }; return stored[identifier] != nil
    }
    func deleteKey(for identifier: String) throws {
        lock.lock(); defer { lock.unlock() }
        if failDelete { throw KeystoreError.unexpectedFail }
        stored.removeValue(forKey: identifier)
    }
}

extension AccountImportTests {
    private enum GenericImportFixture { case mnemonic, seed, json }

    private func genericImportOperation(_ source: GenericImportFixture, keys: KeystoreProtocol,
                                        wallet: MetaAccountModel? = nil, chainId: String? = nil) throws -> BaseOperation<MetaAccountModel> {
        let factory = MetaAccountOperationFactory(keystore: keys)
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList:
            "bottom drive obey lake curtain smoke basket hold race lonely fit walk")
        let seed = "0x" + String(repeating: "3c", count: 32)
        let path = "//public-import"
        let substrateURL = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: Constants.validSrKeystoreName, withExtension: "json"))
        let ethereumURL = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: Constants.validEthereumKeystoreName, withExtension: "json"))
        let json = try String(contentsOf: substrateURL)
        if let wallet {
            let chain = chainId ?? ChainAccountRecordsFixture.polkadotChainId
            switch source {
            case .mnemonic:
                return factory.importChainAccountOperation(request: ChainAccountImportMnemonicRequest(
                    mnemonic: mnemonic, username: wallet.name, derivationPath: path, cryptoType: .sr25519,
                    isEthereum: false, meta: wallet, chainId: chain))
            case .seed:
                return factory.importChainAccountOperation(request: ChainAccountImportSeedRequest(
                    seed: seed, username: wallet.name, derivationPath: path, cryptoType: .sr25519,
                    isEthereum: false, meta: wallet, chainId: chain))
            case .json:
                return factory.importChainAccountOperation(request: ChainAccountImportKeystoreRequest(
                    keystore: json, password: Constants.validSrKeystorePassword, username: wallet.name,
                    cryptoType: .sr25519, isEthereum: false, meta: wallet, chainId: chain))
            }
        }
        switch source {
        case .mnemonic:
            return factory.newMetaAccountOperation(request: MetaAccountImportMnemonicRequest(
                mnemonic: mnemonic, username: "Public atomic import", substrateDerivationPath: path,
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum, cryptoType: .sr25519,
                defaultChainId: nil), isBackuped: true)
        case .seed:
            return factory.newMetaAccountOperation(request: MetaAccountImportSeedRequest(
                substrateSeed: seed, ethereumSeed: seed, username: "Public atomic import",
                substrateDerivationPath: path, ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: .sr25519), isBackuped: true)
        case .json:
            return factory.newMetaAccountOperation(request: MetaAccountImportKeystoreRequest(
                substrateKeystore: json, ethereumKeystore: try String(contentsOf: ethereumURL),
                substratePassword: Constants.validSrKeystorePassword,
                ethereumPassword: Constants.validEthereumKeystorePassword,
                username: "Public atomic import", cryptoType: .sr25519), isBackuped: true)
        }
    }

    private func genericOriginalWallet(_ keys: GenericImportFaultKeychain) throws -> MetaAccountModel {
        // Healthy original wallet with actual derived keys, separately committed before a fault.
        let operation = try nativeTonRecoveryOperation(keys)
        operation.start()
        let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        (operation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        return wallet
    }

    func testGenericMnemonicRootIntermediateWriteRollsBack() throws { try genericIntermediate(.mnemonic) }
    func testGenericSeedRootIntermediateWriteRollsBack() throws { try genericIntermediate(.seed) }
    func testGenericJsonRootIntermediateWriteRollsBack() throws { try genericIntermediate(.json) }
    func testGenericMnemonicChainIntermediateWriteRollsBack() throws { try genericIntermediate(.mnemonic, chain: true) }
    func testGenericSeedChainIntermediateWriteRollsBack() throws { try genericIntermediate(.seed, chain: true) }
    func testGenericJsonChainMutationThenFailureRollsBack() throws { try genericIntermediate(.json, chain: true) }

    private func genericIntermediate(_ source: GenericImportFixture, chain: Bool = false) throws {
        let keys = GenericImportFaultKeychain()
        let oldWallet = try genericOriginalWallet(keys)
        let before = keys.snapshot
        let operation = try genericImportOperation(source, keys: keys, wallet: chain ? oldWallet : nil)
        // JSON per-chain has one write. A write-then-error probes ambiguous transport failure separately.
        keys.resetFault(at: chain && source == .json ? 1 : 2, afterMutation: chain && source == .json)
        operation.start()
        XCTAssertThrowsError(try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
        XCTAssertEqual(keys.snapshot, before, "Failed import must restore the exact prior key inventory")
    }

    func testGenericMnemonicRootFailedSettingsRemovesNewKeys() throws { try genericSettings(.mnemonic, fails: true) }
    func testGenericSeedRootFailedSettingsRemovesNewKeys() throws { try genericSettings(.seed, fails: true) }
    func testGenericJsonRootFailedSettingsRemovesNewKeys() throws { try genericSettings(.json, fails: true) }
    func testGenericMnemonicChainFailedSettingsRemovesNewKeys() throws { try genericSettings(.mnemonic, chain: true, fails: true) }
    func testGenericSeedChainFailedSettingsRemovesNewKeys() throws { try genericSettings(.seed, chain: true, fails: true) }
    func testGenericJsonChainFailedSettingsRemovesNewKeys() throws { try genericSettings(.json, chain: true, fails: true) }
    func testGenericMnemonicRootAcknowledgedSettingsKeepsKeys() throws { try genericSettings(.mnemonic, fails: false) }
    func testGenericSeedRootAcknowledgedSettingsKeepsKeys() throws { try genericSettings(.seed, fails: false) }
    func testGenericJsonRootAcknowledgedSettingsKeepsKeys() throws { try genericSettings(.json, fails: false) }

    private func genericSettings(_ source: GenericImportFixture, chain: Bool = false, fails: Bool) throws {
        let keys = GenericImportFaultKeychain()
        let oldWallet = try genericOriginalWallet(keys)
        let before = keys.snapshot
        let healthy = UserDataStorageTestFacade()
        let storage = ControllableImportStorageFacade(healthy)
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: OperationQueue())
        try AccountCreationHelper.selectMetaAccount(oldWallet, settings: settings)
        storage.service.failureEnabled = fails
        let events = MockEventCenterProtocol()
        stub(events) { stub in when(stub.notify(with: any())).thenDoNothing() }
        let output = MockAccountImportInteractorOutputProtocol()
        let settled = expectation(description: "Actual settings result")
        stub(output) { stub in
            when(stub.didCompleteAccountImport()).then { XCTAssertFalse(fails); settled.fulfill() }
            when(stub.didReceiveAccountImport(error: any())).then { _ in XCTAssertTrue(fails); settled.fulfill() }
        }
        let interactor = AccountImportInteractor(
            accountOperationFactory: MetaAccountOperationFactory(keystore: keys),
            accountRepository: AnyDataProviderRepository(AccountRepositoryFactory(storageFacade: storage)
                .createMetaAccountRepository(for: nil, sortDescriptors: [])),
            operationManager: OperationManager(), settings: settings,
            keystoreImportService: KeystoreImportService(logger: Logger.shared), eventCenter: events,
            defaultSource: .mnemonic, walletRecordsInspector: StoredWalletRecordsInspector(storageFacade: storage))
        interactor.presenter = output
        let operation = try genericImportOperation(source, keys: keys, wallet: chain ? oldWallet : nil)
        interactor.importAccountUsingOperation(operation)
        wait(for: [settled], timeout: 15)
        let original = try XCTUnwrap(ChainAccountRecordsFixture.wallets(in: healthy).first { $0.metaId == oldWallet.metaId })
        XCTAssertEqual(original, oldWallet)
        for (tag, value) in before { XCTAssertEqual(keys.snapshot[tag], value) }
        if fails {
            XCTAssertEqual(settings.value, oldWallet)
            XCTAssertEqual(keys.snapshot, before, "A failed wallet save must not leave new key material")
            XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: healthy).count, 1)
        } else {
            let imported = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            XCTAssertEqual(settings.value?.metaId, imported.metaId)
            XCTAssertNotEqual(keys.snapshot, before)
            XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: healthy).count, 2)
            try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
            XCTAssertNotEqual(keys.snapshot, before, "Acknowledgement seals ownership against later rollback")
        }
        withExtendedLifetime((interactor, output, operation)) {}
    }
}

extension AccountImportTests {
    func testGenericMnemonicChainFailedWriteRestoresPriorOpaquePayloads() throws {
        try genericExistingPayloads(.mnemonic, settingsFailure: false)
    }
    func testGenericSeedChainFailedWriteRestoresPriorOpaquePayloads() throws {
        try genericExistingPayloads(.seed, settingsFailure: false)
    }
    func testGenericJsonChainFailedWriteRestoresPriorOpaquePayloads() throws {
        try genericExistingPayloads(.json, settingsFailure: false)
    }
    func testGenericMnemonicChainFailedSettingsRestoresPriorOpaquePayloads() throws {
        try genericExistingPayloads(.mnemonic, settingsFailure: true)
    }
    func testGenericSeedChainFailedSettingsRestoresPriorOpaquePayloads() throws {
        try genericExistingPayloads(.seed, settingsFailure: true)
    }
    func testGenericJsonChainFailedSettingsRestoresPriorOpaquePayloads() throws {
        try genericExistingPayloads(.json, settingsFailure: true)
    }

    private func genericExistingPayloads(_ source: GenericImportFixture, settingsFailure: Bool) throws {
        let keys = GenericImportFaultKeychain()
        let root = try genericOriginalWallet(keys)
        let originalRootKeys = keys.snapshot
        let first = try genericImportOperation(source, keys: keys, wallet: root)
        first.start()
        let wallet = try first.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        (first as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        let targetTags = Set(keys.snapshot.keys).subtracting(originalRootKeys.keys)
        XCTAssertFalse(targetTags.isEmpty)
        // Preservation is required even for historical/unverified opaque payloads.
        // The separately derived original root remains healthy and byte-identical.
        for tag in targetTags { try keys.saveKey(Data(("prior opaque fixture:" + tag).utf8), with: tag) }
        let before = keys.snapshot
        let operation = try genericImportOperation(source, keys: keys, wallet: wallet)
        if !settingsFailure {
            keys.resetFault(at: source == .json ? 1 : 2, afterMutation: source == .json)
            operation.start()
            XCTAssertThrowsError(try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
        } else {
            operation.start()
            let imported = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let healthy = UserDataStorageTestFacade()
            let storage = ControllableImportStorageFacade(healthy)
            let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: OperationQueue())
            try AccountCreationHelper.selectMetaAccount(wallet, settings: settings)
            storage.service.failureEnabled = true
            let failed = expectation(description: "Prior-payload actual storage rejection")
            settings.save(value: imported, runningCompletionIn: .main) { result in
                if case .success = result { XCTFail("Expected actual store failure") }
                do { try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges() }
                catch { XCTFail("Rollback failed: \(error)") }
                failed.fulfill()
            }
            wait(for: [failed], timeout: 10)
            XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: healthy), [wallet])
        }
        XCTAssertEqual(keys.snapshot, before, "No failed operation owns a replacement of prior opaque material")
        for (tag, value) in originalRootKeys { XCTAssertEqual(keys.snapshot[tag], value) }
    }

    func testGenericSameByteNewerCommitSurvivesOlderFailedSave() throws {
        let keys = GenericImportFaultKeychain()
        let wallet = try genericOriginalWallet(keys)
        let original = keys.snapshot
        let first = try genericImportOperation(.mnemonic, keys: keys, wallet: wallet)
        first.start()
        let firstValue = try first.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let afterFirst = keys.snapshot
        let second = try genericImportOperation(.mnemonic, keys: keys, wallet: wallet)
        second.start()
        let secondValue = try second.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertEqual(secondValue, firstValue)
        XCTAssertEqual(keys.snapshot, afterFirst, "Newer write deliberately contains identical bytes")
        XCTAssertNotEqual(afterFirst, original)
        let healthy = UserDataStorageTestFacade()
        let storage = ControllableImportStorageFacade(healthy)
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: OperationQueue())
        try AccountCreationHelper.selectMetaAccount(secondValue, settings: settings)
        (second as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        storage.service.failureEnabled = true
        let failed = expectation(description: "Older save fails after newer acknowledgement")
        settings.save(value: firstValue, runningCompletionIn: .main) { result in
            if case .success = result { XCTFail("Expected actual storage failure") }
            do { try (first as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges() }
            catch { XCTFail("Older rollback failed: \(error)") }
            failed.fulfill()
        }
        wait(for: [failed], timeout: 10)
        XCTAssertEqual(keys.snapshot, afterFirst, "Byte equality cannot transfer newer key ownership to the old failed import")
        XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: healthy), [secondValue])
    }

    func testGenericOverlappingFailuresDoNotResurrectOlderKeys() throws {
        for olderFailsFirst in [true, false] {
            let keys = GenericImportFaultKeychain()
            let wallet = try genericOriginalWallet(keys)
            let original = keys.snapshot
            let first = try genericImportOperation(.mnemonic, keys: keys, wallet: wallet)
            first.start()
            _ = try first.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let second = try genericImportOperation(.mnemonic, keys: keys, wallet: wallet)
            second.start()
            _ = try second.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            for operation in olderFailsFirst ? [first, second] : [second, first] {
                try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
            }
            XCTAssertEqual(keys.snapshot, original, "Two failed overlapping imports must not resurrect one another")
        }
    }
}

extension AccountImportTests {
    func testGenericSeparateSystemKeychainInstancesShareWriteOwnership() throws {
        let tag = "public-generic-import-ownership-" + UUID().uuidString
        let firstStore = Keychain(), secondStore = Keychain()
        XCTAssertFalse(try firstStore.checkKey(for: tag))
        defer { try? firstStore.deleteKeyIfExists(for: tag) }
        let first = ImportKeychainTransaction(keystore: firstStore)
        let second = ImportKeychainTransaction(keystore: secondStore)
        let bytes = Data("public-identical-overlap".utf8)
        try first.saveKey(bytes, with: tag)
        try second.saveKey(bytes, with: tag)
        second.commit()
        try first.rollback()
        XCTAssertEqual(try secondStore.fetchKey(for: tag), bytes)
    }

    func testGenericFailedDeleteIsReportedAndRetryPreservesOtherKeys() throws {
        let keys = GenericImportFaultKeychain()
        try keys.addKey(Data([7]), with: "unrelated")
        let transaction = ImportKeychainTransaction(keystore: keys)
        try transaction.saveKey(Data([1]), with: "new-public-key")
        keys.failDelete = true
        XCTAssertThrowsError(try transaction.rollback())
        XCTAssertEqual(keys.snapshot, ["new-public-key": Data([1]), "unrelated": Data([7])])
        keys.failDelete = false
        try transaction.rollback()
        XCTAssertEqual(keys.snapshot, ["unrelated": Data([7])])
    }

    func testGenericUnreadablePriorValueCannotBeOverwritten() throws {
        let keys = GenericImportFaultKeychain()
        try keys.addKey(Data([7]), with: "existing")
        keys.failRead = true
        let transaction = ImportKeychainTransaction(keystore: keys)
        XCTAssertThrowsError(try transaction.saveKey(Data([1]), with: "existing"))
        XCTAssertEqual(keys.snapshot, ["existing": Data([7])])
        keys.failRead = false
        try transaction.rollback()
    }

    func testGenericDifferentExternalWriteIsPreservedOnRollback() throws {
        let keys = GenericImportFaultKeychain()
        let transaction = ImportKeychainTransaction(keystore: keys)
        try transaction.saveKey(Data([1]), with: "public-key")
        try keys.saveKey(Data([2]), with: "public-key")
        try transaction.rollback()
        XCTAssertEqual(keys.snapshot, ["public-key": Data([2])])
    }

    func testGenericUnacknowledgedOperationReleaseRemovesKeys() throws {
        let keys = GenericImportFaultKeychain()
        let original = try genericOriginalWallet(keys)
        let before = keys.snapshot
        var operation: BaseOperation<MetaAccountModel>? = try genericImportOperation(.mnemonic, keys: keys, wallet: original)
        operation?.start()
        _ = try XCTUnwrap(operation).extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertNotEqual(keys.snapshot, before)
        operation = nil
        XCTAssertEqual(keys.snapshot, before)
    }

    func testGenericConfirmationAcknowledgesKeys() throws { try genericConfirmation(adding: false, fails: false) }
    func testGenericConfirmationRollsBackFailedKeys() throws { try genericConfirmation(adding: false, fails: true) }
    func testGenericAddConfirmationAcknowledgesKeys() throws { try genericConfirmation(adding: true, fails: false) }
    func testGenericAddConfirmationRollsBackFailedKeys() throws { try genericConfirmation(adding: true, fails: true) }

    private func genericConfirmation(adding: Bool, fails: Bool) throws {
        let keys = GenericImportFaultKeychain()
        let original = try genericOriginalWallet(keys)
        let before = keys.snapshot
        let healthy = UserDataStorageTestFacade()
        let storage = ControllableImportStorageFacade(healthy)
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: OperationQueue())
        try AccountCreationHelper.selectMetaAccount(original, settings: settings)
        storage.service.failureEnabled = fails
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList:
                "bottom drive obey lake curtain smoke basket hold race lonely fit walk"),
            username: "Public confirmation", substrateDerivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519, defaultChainId: nil)
        let events = MockEventCenterProtocol()
        stub(events) { stub in when(stub.notify(with: any())).thenDoNothing() }
        let factory = MetaAccountOperationFactory(keystore: keys)
        let repository = AnyDataProviderRepository(AccountRepositoryFactory(storageFacade: storage)
            .createMetaAccountRepository(for: nil, sortDescriptors: []))
        let interactor: BaseAccountConfirmInteractor
        if adding {
            interactor = AddAccount.AccountConfirmInteractor(flow: .wallet(request), accountOperationFactory: factory,
                accountRepository: repository, operationManager: OperationManager(), settings: settings, eventCenter: events)
        } else {
            interactor = AccountConfirmInteractor(flow: .wallet(request), accountOperationFactory: factory,
                accountRepository: repository, settings: settings, operationManager: OperationManager(), eventCenter: events)
        }
        let output = MockAccountConfirmInteractorOutputProtocol()
        let settled = expectation(description: "Actual confirmation store result")
        stub(output) { stub in
            when(stub.didCompleteConfirmation()).then { XCTAssertFalse(fails); settled.fulfill() }
            when(stub.didReceive(error: any())).then { _ in XCTAssertTrue(fails); settled.fulfill() }
        }
        interactor.presenter = output
        var operation: BaseOperation<MetaAccountModel>? = factory.newMetaAccountOperation(request: request, isBackuped: true)
        interactor.createAccountUsingOperation(try XCTUnwrap(operation))
        wait(for: [settled], timeout: 15)
        let after = keys.snapshot
        if fails { XCTAssertEqual(after, before); XCTAssertEqual(settings.value, original) }
        else { XCTAssertNotEqual(after, before); XCTAssertNotEqual(settings.value?.metaId, original.metaId) }
        try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        operation = nil
        XCTAssertEqual(keys.snapshot, after, "Successful acknowledgement must seal keys before the operation is released")
        withExtendedLifetime((interactor, output)) {}
    }
}

private final class GenericImportCallbackRecorder: BackupPasswordInteractorOutput, GetPreinstalledWalletInteractorOutput,
    BackupCreatePasswordInteractorOutput, AccountImportInteractorOutputProtocol, AccountConfirmInteractorOutputProtocol {
    let completion: (Error?) -> Void
    init(_ completion: @escaping (Error?) -> Void) { self.completion = completion }
    func didReceiveAccountImport(metadata: MetaAccountImportMetadata) {}
    func didSuggestKeystore(text: String, preferredInfo: MetaAccountImportPreferredInfo?) {}
    func didFailToDeriveMetadataFromKeystore() {}
    func didReceive(words: [String], afterConfirmationFail: Bool) {}
    func didCompleteConfirmation() { completion(nil) }
    func didReceiveAccountImport(error: Error) { completion(error) }
    func didCompleteAccountImport() { completion(nil) }
    func didReceive(error: Error) { completion(error) }
    func didComplete(accountsNotRestored: [ChainAccountModel]) { completion(nil) }
    func didReceiveBackup(result: Result<OpenBackupAccount, Error>) {}
    func showGoogleIssueError() {}
    func handleQRService(error: Error) {}
    func handleAddress(_ address: String) {}
    func handleMatched(code: String) {}
    func qrCapture(service: QRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession) {}
    func qrCapture(service: QRCaptureServiceProtocol, didMatch code: String) {}
    func qrCapture(service: QRCaptureServiceProtocol, didReceive error: Error) {}
}

private final class GenericImportRecordingFactory: MetaAccountOperationFactoryProtocol {
    let factory: MetaAccountOperationFactory
    weak var operation: BaseOperation<MetaAccountModel>?
    init(keys: KeystoreProtocol) { factory = MetaAccountOperationFactory(keystore: keys) }
    private func record(_ value: BaseOperation<MetaAccountModel>) -> BaseOperation<MetaAccountModel> {
        operation = value; return value
    }
    func newMetaAccountOperation(request: MetaAccountImportMnemonicRequest, isBackuped: Bool) -> BaseOperation<MetaAccountModel> {
        record(factory.newMetaAccountOperation(request: request, isBackuped: isBackuped))
    }
    func newMetaAccountOperation(request: MetaAccountImportSeedRequest, isBackuped: Bool) -> BaseOperation<MetaAccountModel> {
        record(factory.newMetaAccountOperation(request: request, isBackuped: isBackuped))
    }
    func newMetaAccountOperation(request: MetaAccountImportKeystoreRequest, isBackuped: Bool) -> BaseOperation<MetaAccountModel> {
        record(factory.newMetaAccountOperation(request: request, isBackuped: isBackuped))
    }
    func importChainAccountOperation(request: ChainAccountImportMnemonicRequest) -> BaseOperation<MetaAccountModel> {
        record(factory.importChainAccountOperation(request: request))
    }
    func importChainAccountOperation(request: ChainAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        record(factory.importChainAccountOperation(request: request))
    }
    func importChainAccountOperation(request: ChainAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel> {
        record(factory.importChainAccountOperation(request: request))
    }
}

extension AccountImportTests {
    func testGenericCloudRestoreAcknowledgesKeys() throws { try genericOtherImportCaller(qr: false, fails: false) }
    func testGenericCloudRestoreRollsBackFailedKeys() throws { try genericOtherImportCaller(qr: false, fails: true) }
    func testGenericQrImportAcknowledgesKeys() throws { try genericOtherImportCaller(qr: true, fails: false) }
    func testGenericQrImportRollsBackFailedKeys() throws { try genericOtherImportCaller(qr: true, fails: true) }

    private func genericOtherImportCaller(qr: Bool, fails: Bool) throws {
        let keys = GenericImportFaultKeychain()
        let oldWallet = try genericOriginalWallet(keys)
        let before = keys.snapshot
        let healthy = UserDataStorageTestFacade()
        let storage = ControllableImportStorageFacade(healthy)
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: OperationQueue())
        try AccountCreationHelper.selectMetaAccount(oldWallet, settings: settings)
        storage.service.failureEnabled = fails
        let events = MockEventCenterProtocol()
        stub(events) { stub in when(stub.notify(with: any())).thenDoNothing() }
        let factory = MetaAccountOperationFactory(keystore: keys)
        let repository = AnyDataProviderRepository(AccountRepositoryFactory(storageFacade: storage)
            .createMetaAccountRepository(for: nil, sortDescriptors: []))
        let done = expectation(description: "Actual additional caller acknowledgement")
        let output = GenericImportCallbackRecorder { error in XCTAssertEqual(error != nil, fails); done.fulfill() }
        let interactor: BaseAccountImportInteractor
        if qr {
            let actual = GetPreinstalledWalletInteractor(qrService: QRServiceDefault(),
                qrScanService: QRCaptureServiceFactory().createService(delegate: nil, delegateQueue: nil),
                accountOperationFactory: factory, accountRepository: repository, operationManager: OperationManager(),
                keystoreImportService: KeystoreImportService(logger: Logger.shared), defaultSource: .mnemonic,
                settings: settings, eventCenter: events)
            actual.setup(with: output); interactor = actual
        } else {
            let actual = BackupPasswordInteractor(accountOperationFactory: factory, accountRepository: repository,
                operationManager: OperationManager(), settings: settings,
                keystoreImportService: KeystoreImportService(logger: Logger.shared), eventCenter: events,
                defaultSource: .mnemonic)
            actual.setup(with: output); interactor = actual
        }
        let operation = try genericImportOperation(.mnemonic, keys: keys)
        interactor.importAccountUsingOperation(operation)
        wait(for: [done], timeout: 15)
        if fails {
            XCTAssertEqual(keys.snapshot, before)
            XCTAssertEqual(settings.value, oldWallet)
        } else {
            let saved = try XCTUnwrap(settings.value)
            let committed = keys.snapshot
            XCTAssertNotEqual(committed, before)
            try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
            XCTAssertEqual(keys.snapshot, committed, "Actual store acknowledgement must seal key ownership")
            XCTAssertTrue(try ChainAccountRecordsFixture.wallets(in: healthy).contains { $0.metaId == saved.metaId })
        }
        withExtendedLifetime((interactor, output, operation)) {}
    }

    func testGenericCloudCreateStoreFailureRollsBackKeys() throws { try genericCloudCreate(fails: true) }
    func testGenericCloudCreateLaterCloudFailurePreservesAcknowledgedKeys() throws { try genericCloudCreate(fails: false) }

    private func genericCloudCreate(fails: Bool) throws {
        let keys = GenericImportFaultKeychain()
        let oldWallet = try genericOriginalWallet(keys)
        let before = keys.snapshot
        let healthy = UserDataStorageTestFacade()
        let storage = ControllableImportStorageFacade(healthy)
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: OperationQueue())
        try AccountCreationHelper.selectMetaAccount(oldWallet, settings: settings)
        storage.service.failureEnabled = fails
        let events = MockEventCenterProtocol()
        stub(events) { stub in when(stub.notify(with: any())).thenDoNothing() }
        let factory = GenericImportRecordingFactory(keys: keys)
        let request = MetaAccountImportMnemonicRequest(mnemonic: try IRMnemonicCreator().mnemonic(fromList:
            "bottom drive obey lake curtain smoke basket hold race lonely fit walk"), username: "Public cloud create",
            substrateDerivationPath: "", ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519, defaultChainId: nil)
        let interactor = BackupCreatePasswordInteractor(createPasswordFlow: .createWallet(request),
            accountOperationFactory: factory,
            accountRepository: AnyDataProviderRepository(AccountRepositoryFactory(storageFacade: storage)
                .createMetaAccountRepository(for: nil, sortDescriptors: [])),
            settings: settings, operationManager: OperationManager(), eventCenter: events,
            secretManager: MockSecretStoreManagerProtocol(), keystore: keys,
            exportJsonWrapper: KeystoreExportWrapper(keystore: keys))
        let done = expectation(description: "Store rejection or later unavailable cloud")
        let output = GenericImportCallbackRecorder { error in
            XCTAssertNotNil(error)
            if !fails { XCTAssertTrue(error is BackupCreatePasswordError) }
            done.fulfill()
        }
        interactor.setup(with: output)
        interactor.cloudStorage = nil
        interactor.createAndBackupAccount(password: "public-cloud-fixture")
        wait(for: [done], timeout: 15)
        if fails {
            XCTAssertEqual(keys.snapshot, before)
            XCTAssertEqual(settings.value, oldWallet)
        } else {
            let acknowledged = keys.snapshot
            XCTAssertNotEqual(acknowledged, before)
            XCTAssertNotEqual(settings.value?.metaId, oldWallet.metaId)
            try (factory.operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
            XCTAssertEqual(keys.snapshot, acknowledged, "Later cloud failure cannot undo the acknowledged local wallet")
            XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: healthy).count, 2)
        }
        withExtendedLifetime((interactor, output)) {}
    }

    func testGenericDependentRecoveryRetainsOlderPendingRootKeys() throws {
        try genericRootDependency(olderFailsFirst: false)
    }
    func testGenericRecoveryCannotPublishAlreadyRolledBackProvisionalRoot() throws {
        try genericRootDependency(olderFailsFirst: true)
    }

    private func genericRootDependency(olderFailsFirst: Bool) throws {
        let keys = GenericImportFaultKeychain()
        let rootOperation = MetaAccountOperationFactory(keystore: keys).newMetaAccountOperation(
            request: MetaAccountImportMnemonicRequest(mnemonic: try IRMnemonicCreator().mnemonic(fromList:
                "bottom drive obey lake curtain smoke basket hold race lonely fit walk"), username: "Provisional root",
                substrateDerivationPath: "", ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: .sr25519, defaultChainId: nil), isBackuped: false)
        rootOperation.start()
        let wallet = try rootOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let before = keys.snapshot
        let rootTag = KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        let expected = try XCTUnwrap(before[rootTag])
        if olderFailsFirst { try (rootOperation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges() }
        let recovery = MetaAccountOperationFactory(keystore: keys).importChainAccountOperation(
            request: ChainAccountImportMnemonicRequest(mnemonic: try IRMnemonicCreator().mnemonic(fromList:
                "bottom drive obey lake curtain smoke basket hold race lonely fit walk"), username: wallet.name,
                derivationPath: "", cryptoType: .sr25519, isEthereum: false, meta: wallet,
                chainId: UniversalWalletRegistry.bitcoinMainnet.chainId))
        recovery.start()
        if olderFailsFirst {
            XCTAssertThrowsError(try recovery.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
            XCTAssertTrue(keys.snapshot.isEmpty)
        } else {
            let recovered = try recovery.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let storage = UserDataStorageTestFacade()
            let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: OperationQueue())
            try AccountCreationHelper.selectMetaAccount(recovered, settings: settings,
                importOperation: recovery as? PersistenceBoundKeychainOperation)
            try (rootOperation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
            XCTAssertEqual(keys.snapshot[rootTag], expected, "Saved dependent wallet still needs the original root signer")
            XCTAssertEqual(keys.snapshot, before)
        }
    }
}

extension AccountImportTests {
    private enum GenericCaller: CaseIterable { case root, adding, confirmation, addConfirmation, cloudRestore, qr, cloudCreate }

    private func genericCaller(_ caller: GenericCaller, keys: KeystoreProtocol, storage: StorageFacadeProtocol,
                               settings: SelectedWalletSettings, manager: OperationManagerProtocol,
                               events: EventCenterProtocol, output: GenericImportCallbackRecorder) throws -> AnyObject {
        let factory = MetaAccountOperationFactory(keystore: keys)
        let repository = AnyDataProviderRepository(AccountRepositoryFactory(storageFacade: storage)
            .createMetaAccountRepository(for: nil, sortDescriptors: []))
        let service = KeystoreImportService(logger: Logger.shared)
        let request = MetaAccountImportMnemonicRequest(mnemonic: try IRMnemonicCreator().mnemonic(fromList:
            "bottom drive obey lake curtain smoke basket hold race lonely fit walk"), username: "Public held caller",
            substrateDerivationPath: "", ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519, defaultChainId: nil)
        switch caller {
        case .root:
            let owner = AccountImportInteractor(accountOperationFactory: factory, accountRepository: repository,
                operationManager: manager, settings: settings, keystoreImportService: service, eventCenter: events,
                defaultSource: .mnemonic, walletRecordsInspector: StoredWalletRecordsInspector(storageFacade: storage))
            owner.presenter = output; return owner
        case .adding:
            let owner = AddAccount.AccountImportInteractor(accountOperationFactory: factory, accountRepository: repository,
                operationManager: manager, settings: settings, keystoreImportService: service,
                eventCenter: events, defaultSource: .mnemonic)
            owner.presenter = output; return owner
        case .confirmation:
            let owner = AccountConfirmInteractor(flow: .wallet(request), accountOperationFactory: factory,
                accountRepository: repository, settings: settings, operationManager: manager, eventCenter: events)
            owner.presenter = output; return owner
        case .addConfirmation:
            let owner = AddAccount.AccountConfirmInteractor(flow: .wallet(request), accountOperationFactory: factory,
                accountRepository: repository, operationManager: manager, settings: settings, eventCenter: events)
            owner.presenter = output; return owner
        case .cloudRestore:
            let owner = BackupPasswordInteractor(accountOperationFactory: factory, accountRepository: repository,
                operationManager: manager, settings: settings, keystoreImportService: service,
                eventCenter: events, defaultSource: .mnemonic)
            owner.setup(with: output); return owner
        case .qr:
            let owner = GetPreinstalledWalletInteractor(qrService: QRServiceDefault(),
                qrScanService: QRCaptureServiceFactory().createService(delegate: nil, delegateQueue: nil),
                accountOperationFactory: factory, accountRepository: repository, operationManager: manager,
                keystoreImportService: service, defaultSource: .mnemonic, settings: settings, eventCenter: events)
            owner.setup(with: output); return owner
        case .cloudCreate:
            let owner = BackupCreatePasswordInteractor(createPasswordFlow: .createWallet(request),
                accountOperationFactory: factory, accountRepository: repository, settings: settings,
                operationManager: manager, eventCenter: events, secretManager: MockSecretStoreManagerProtocol(),
                keystore: keys, exportJsonWrapper: KeystoreExportWrapper(keystore: keys))
            owner.setup(with: output); return owner
        }
    }

    private func genericIssue(_ operation: BaseOperation<MetaAccountModel>, to owner: AnyObject) {
        if let importer = owner as? BaseAccountImportInteractor { importer.importAccountUsingOperation(operation) }
        else if let creator = owner as? BaseAccountConfirmInteractor { creator.createAccountUsingOperation(operation) }
        else { XCTFail("Unsupported actual caller") }
    }

    @MainActor
    private func genericReleasedCaller(_ caller: GenericCaller, fails: Bool, beforeWrite: Bool = false) async throws {
        let keys = GenericImportFaultKeychain()
        let original = try genericOriginalWallet(keys)
        let before = keys.snapshot
        let healthy = UserDataStorageTestFacade()
        let storage = ControllableImportStorageFacade(healthy)
        let saveQueue = OperationQueue()
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: saveQueue)
        try AccountCreationHelper.selectMetaAccount(original, settings: settings)
        saveQueue.isSuspended = true
        defer { saveQueue.isSuspended = false }
        let importQueue = OperationQueue()
        importQueue.isSuspended = beforeWrite
        defer { importQueue.isSuspended = false }
        let manager = OperationManager(operationQueue: importQueue)
        let events = MockEventCenterProtocol()
        stub(events) { stub in when(stub.notify(with: any())).then { _ in XCTFail("Released caller notified UI") } }
        let output = GenericImportCallbackRecorder { _ in XCTFail("Released caller invoked output") }
        var owner: AnyObject? = try genericCaller(caller, keys: keys, storage: storage, settings: settings,
            manager: manager, events: events, output: output)
        weak var oldOwner = owner
        let operation = try genericImportOperation(.mnemonic, keys: keys)
        genericIssue(operation, to: try XCTUnwrap(owner))
        if !beforeWrite {
            await tonWait { settings.value?.metaId != original.metaId && saveQueue.operationCount > 0 }
            XCTAssertNotEqual(settings.value?.metaId, original.metaId)
            XCTAssertNotEqual(keys.snapshot, before)
        }
        owner = nil
        await tonWait { oldOwner == nil }
        XCTAssertNil(oldOwner)
        storage.service.failureEnabled = fails
        if beforeWrite {
            importQueue.isSuspended = false
            await tonWait { operation.isFinished && keys.snapshot == before }
            XCTAssertEqual(keys.snapshot, before, "Unissued save must explicitly roll back even while the operation is retained")
            XCTAssertEqual(saveQueue.operationCount, 0)
            XCTAssertEqual(settings.value, original)
        } else {
            var settled = false
            settings.performAfterPendingSaves { DispatchQueue.main.async { settled = true } }
            saveQueue.isSuspended = false
            await tonWait { settled }
            if fails {
                XCTAssertEqual(settings.value, original)
                XCTAssertEqual(keys.snapshot, before, "Cleanup must not depend on operation deinit")
            } else {
                XCTAssertNotEqual(settings.value?.metaId, original.metaId)
                let committed = keys.snapshot
                try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
                XCTAssertEqual(keys.snapshot, committed)
            }
        }
        storage.service.failureEnabled = false
        XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: healthy).count, beforeWrite || fails ? 1 : 2)
        withExtendedLifetime((operation, manager, output)) {}
    }

    @MainActor func testGenericRootAcknowledgesAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.root, fails: false, beforeWrite: false)
    }

    @MainActor func testGenericRootRollsBackAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.root, fails: true, beforeWrite: false)
    }

    @MainActor func testGenericRootRollsBackBeforeSaveAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.root, fails: false, beforeWrite: true)
    }

    @MainActor func testGenericAddAcknowledgesAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.adding, fails: false, beforeWrite: false)
    }

    @MainActor func testGenericAddRollsBackAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.adding, fails: true, beforeWrite: false)
    }

    @MainActor func testGenericAddRollsBackBeforeSaveAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.adding, fails: false, beforeWrite: true)
    }

    @MainActor func testGenericConfirmationAcknowledgesAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.confirmation, fails: false, beforeWrite: false)
    }

    @MainActor func testGenericConfirmationRollsBackAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.confirmation, fails: true, beforeWrite: false)
    }

    @MainActor func testGenericConfirmationRollsBackBeforeSaveAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.confirmation, fails: false, beforeWrite: true)
    }

    @MainActor func testGenericAddConfirmationAcknowledgesAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.addConfirmation, fails: false, beforeWrite: false)
    }

    @MainActor func testGenericAddConfirmationRollsBackAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.addConfirmation, fails: true, beforeWrite: false)
    }

    @MainActor func testGenericAddConfirmationRollsBackBeforeSaveAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.addConfirmation, fails: false, beforeWrite: true)
    }

    @MainActor func testGenericCloudRestoreAcknowledgesAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.cloudRestore, fails: false, beforeWrite: false)
    }

    @MainActor func testGenericCloudRestoreRollsBackAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.cloudRestore, fails: true, beforeWrite: false)
    }

    @MainActor func testGenericCloudRestoreRollsBackBeforeSaveAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.cloudRestore, fails: false, beforeWrite: true)
    }

    @MainActor func testGenericQRAcknowledgesAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.qr, fails: false, beforeWrite: false)
    }

    @MainActor func testGenericQRRollsBackAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.qr, fails: true, beforeWrite: false)
    }

    @MainActor func testGenericQRRollsBackBeforeSaveAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.qr, fails: false, beforeWrite: true)
    }

    @MainActor func testGenericCloudCreateAcknowledgesAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.cloudCreate, fails: false, beforeWrite: false)
    }

    @MainActor func testGenericCloudCreateRollsBackAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.cloudCreate, fails: true, beforeWrite: false)
    }

    @MainActor func testGenericCloudCreateRollsBackBeforeSaveAfterOwnerRelease() async throws {
        try await genericReleasedCaller(.cloudCreate, fails: false, beforeWrite: true)
    }
}

extension AccountImportTests {
    func testGenericDependentChainRetainsProvisionalSigner() throws {
        try genericChainDependency(olderFailsFirst: false, replacement: false)
    }
    func testGenericDependentChainRejectsAlreadyRemovedSigner() throws {
        try genericChainDependency(olderFailsFirst: true, replacement: false)
    }
    func testGenericReplacementDoesNotCommitUnreferencedProvisionalKeys() throws {
        try genericChainDependency(olderFailsFirst: false, replacement: true)
    }
    private func genericChainDependency(olderFailsFirst: Bool, replacement: Bool) throws {
        let keys = GenericImportFaultKeychain()
        let original = try genericOriginalWallet(keys)
        let committedRoot = keys.snapshot
        let first = try genericImportOperation(.mnemonic, keys: keys, wallet: original)
        first.start()
        let provisional = try first.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let provisionalKeys = keys.snapshot.filter { committedRoot[$0.key] == nil }
        XCTAssertFalse(provisionalKeys.isEmpty)
        if olderFailsFirst { try (first as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges() }
        let next = try genericImportOperation(.seed, keys: keys, wallet: provisional,
            chainId: replacement ? nil : "public-second-chain")
        next.start()
        if olderFailsFirst {
            XCTAssertThrowsError(try next.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
            XCTAssertEqual(keys.snapshot, committedRoot)
        } else {
            let saved = try next.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
            try AccountCreationHelper.selectMetaAccount(saved, settings: settings,
                importOperation: next as? PersistenceBoundKeychainOperation)
            try (first as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
            for (tag, value) in provisionalKeys {
                XCTAssertEqual(keys.snapshot[tag], replacement ? nil : value,
                    "Only keys referenced by the saved model should retain a provisional lease")
            }
            for (tag, value) in committedRoot { XCTAssertEqual(keys.snapshot[tag], value) }
        }
    }

    func testGenericDependentFailureReleasesAllProvisionalLeases() throws {
        let keys = GenericImportFaultKeychain()
        let original = try genericOriginalWallet(keys)
        let before = keys.snapshot
        let first = try genericImportOperation(.mnemonic, keys: keys, wallet: original)
        first.start()
        let provisional = try first.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let next = try genericImportOperation(.seed, keys: keys, wallet: provisional, chainId: "public-second-chain")
        next.start()
        _ = try next.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        try (first as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        XCTAssertNotEqual(keys.snapshot, before)
        try (next as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        XCTAssertEqual(keys.snapshot, before)
    }

    func testGenericUnseenHistoricalMissingKeysCanStillImportSeparateAccount() throws {
        let keys = GenericImportFaultKeychain()
        let model = try genericOriginalWallet(keys)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(model)) as? [String: Any])
        object["metaId"] = UUID().uuidString
        let historical = try JSONDecoder().decode(MetaAccountModel.self, from: JSONSerialization.data(withJSONObject: object))
        let missingKeys = GenericImportFaultKeychain()
        let operation = try genericImportOperation(.seed, keys: missingKeys, wallet: historical)
        operation.start()
        let imported = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertEqual(imported.metaId, historical.metaId)
        XCTAssertEqual(imported.legacyTonAccount, historical.legacyTonAccount)
        XCTAssertEqual(imported.chainAccounts.count, 1)
        XCTAssertNil(missingKeys.snapshot[KeystoreTagV2.tonSecretKeyTagForMetaId(historical.metaId)])
        try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        XCTAssertTrue(missingKeys.snapshot.isEmpty)
    }
}

extension AccountImportTests {
    func testGenericProvisionalRootRequirementsSurviveInventoryProjection() throws {
        let keys = GenericImportFaultKeychain()
        let request = MetaAccountImportMnemonicRequest(mnemonic: try IRMnemonicCreator().mnemonic(fromList:
            "bottom drive obey lake curtain smoke basket hold race lonely fit walk"), username: "Projected public root",
            substrateDerivationPath: "", ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519, defaultChainId: nil)
        let first = MetaAccountOperationFactory(keystore: keys).newMetaAccountOperation(request: request, isBackuped: false)
        first.start()
        let provisional = try first.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertFalse(provisional.chainAccounts.isEmpty)
        let projected = provisional.replacingChainAccounts([])
        try (first as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        let next = MetaAccountOperationFactory(keystore: keys).importChainAccountOperation(
            request: ChainAccountImportMnemonicRequest(mnemonic: request.mnemonic, username: projected.name,
                derivationPath: "", cryptoType: .sr25519, isEthereum: false, meta: projected,
                chainId: UniversalWalletRegistry.bitcoinMainnet.chainId))
        next.start()
        XCTAssertThrowsError(try next.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
        XCTAssertTrue(keys.snapshot.isEmpty)
    }

    func testGenericProvisionalChainRequirementsSurviveNetworkAliasCopy() throws {
        let keys = GenericImportFaultKeychain()
        let original = try genericOriginalWallet(keys)
        let before = keys.snapshot
        let first = try genericImportOperation(.mnemonic, keys: keys, wallet: original)
        first.start()
        let provisional = try first.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let account = try XCTUnwrap(provisional.chainAccounts.first)
        let alias = ChainAccountModel(chainId: "0x" + account.chainId, accountId: account.accountId,
            publicKey: account.publicKey, cryptoType: account.cryptoType, ethereumBased: account.ethereumBased)
        let copied = provisional.replacingChainAccounts([alias]).replacingIsBackuped(true)
        try (first as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        let next = try genericImportOperation(.seed, keys: keys, wallet: copied, chainId: "public-second-chain")
        next.start()
        XCTAssertThrowsError(try next.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
        XCTAssertEqual(keys.snapshot, before)
    }
}

extension AccountImportTests {
    @MainActor func testGenericConfirmationRejectsDuplicateUntilWalletAcknowledgement() async throws {
        try await genericDuplicateConfirmation(.confirmation)
    }
    @MainActor func testGenericAddConfirmationRejectsDuplicateUntilWalletAcknowledgement() async throws {
        try await genericDuplicateConfirmation(.addConfirmation)
    }
    @MainActor func testGenericCloudCreateRejectsDuplicateUntilWalletAcknowledgement() async throws {
        try await genericDuplicateConfirmation(.cloudCreate)
    }
    @MainActor private func genericDuplicateConfirmation(_ caller: GenericCaller) async throws {
        let keys = GenericImportFaultKeychain()
        let original = try genericOriginalWallet(keys)
        let storage = UserDataStorageTestFacade()
        let queue = OperationQueue()
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: queue)
        try AccountCreationHelper.selectMetaAccount(original, settings: settings)
        queue.isSuspended = true
        defer { queue.isSuspended = false }
        let events = MockEventCenterProtocol()
        stub(events) { stub in when(stub.notify(with: any())).thenDoNothing() }
        var callbacks = 0
        let output = GenericImportCallbackRecorder { _ in callbacks += 1 }
        let owner = try genericCaller(caller, keys: keys, storage: storage, settings: settings,
            manager: OperationManager(), events: events, output: output)
        let first = try genericImportOperation(.mnemonic, keys: keys)
        let second = try genericImportOperation(.seed, keys: keys)
        genericIssue(first, to: owner)
        await tonWait { settings.value?.metaId != original.metaId && queue.operationCount > 0 }
        let pendingKeys = keys.snapshot
        genericIssue(second, to: owner)
        XCTAssertFalse(second.isExecuting)
        XCTAssertFalse(second.isFinished)
        XCTAssertEqual(keys.snapshot, pendingKeys)
        XCTAssertEqual(callbacks, 0)
        queue.isSuspended = false
        await tonWait { callbacks == 1 }
        XCTAssertEqual(callbacks, 1)
        XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: storage).count, 2)
        try (first as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        XCTAssertEqual(keys.snapshot, pendingKeys)
        genericIssue(second, to: owner)
        await tonWait { callbacks == 2 }
        XCTAssertEqual(callbacks, 2)
        XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: storage).count, 3)
        withExtendedLifetime((owner, output)) {}
    }
}


extension AccountImportTests {
    /// Uses acknowledged current factories and production readers. This is a public-fixture
    /// continuity check, not a reproduction of the separate released historical seed bug.
    func testRawSeedChildImportPreservesAcknowledgedRootAndNativeSigning() throws {
        let keys = GenericImportFaultKeychain()
        let factory = MetaAccountOperationFactory(keystore: keys)
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        let rootSeed = Data(repeating: 0, count: 32)
        let rootOperation = factory.newMetaAccountOperation(request: MetaAccountImportSeedRequest(
            substrateSeed: rootSeed.toHex(includePrefix: false), ethereumSeed: nil,
            username: "Public root continuity", substrateDerivationPath: "", ethereumDerivationPath: nil,
            cryptoType: .sr25519
        ), isBackuped: true)
        rootOperation.start()
        let original = try rootOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        try AccountCreationHelper.selectMetaAccount(
            original,
            settings: settings,
            importOperation: rootOperation as? PersistenceBoundKeychainOperation
        )
        let priorKeys = keys.snapshot
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keys)
        let originalMnemonic = try XCTUnwrap(provider.rootMnemonic(for: original))
        let btcChain = UniversalWalletRegistry.bitcoinMainnetChainModel
        let solChain = UniversalWalletRegistry.solanaMainnetChainModel
        let originalBitcoin = try XCTUnwrap(original.fetch(for: btcChain.accountRequest()))
        let originalSolana = try XCTUnwrap(original.fetch(for: solChain.accountRequest()))
        let address = try XCTUnwrap(UniversalWalletAccountAddressResolver.address(for: btcChain, wallet: original))
        func signedBitcoin(_ phrase: String) throws -> BitcoinBuiltTransaction {
            // Synthetic outpoint, local signature only; never submitted to any node.
            try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: phrase,
                inputs: [BitcoinSpendableUtxo(
                    address: address,
                    txid: String(repeating: "11", count: 32),
                    valueSats: 51000,
                    vout: 0
                )],
                outputs: [BitcoinPaymentOutput(address: address, valueSats: 50000)],
                feeSats: 1000
            )
        }
        let beforeBitcoin = try signedBitcoin(originalMnemonic)
        let childSeed = Data(repeating: 0x3C, count: 32)
        let operation = try genericImportOperation(.seed, keys: keys, wallet: original)
        operation.start()
        let updated = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        try AccountCreationHelper.selectMetaAccount(
            updated,
            settings: settings,
            importOperation: operation as? PersistenceBoundKeychainOperation
        )
        // A post-ack disposal/rollback cannot remove either committed root or child.
        try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
        XCTAssertEqual(settings.value?.metaId, original.metaId)
        for (tag, value) in priorKeys {
            XCTAssertEqual(keys.snapshot[tag], value, tag)
        }
        let child = try XCTUnwrap(updated.chainAccounts.first { $0.chainId == ChainAccountRecordsFixture.polkadotChainId })
        XCTAssertEqual(try keys.fetchKey(for: KeystoreTagV2.substrateSeedTagForMetaId(
            updated.metaId, accountId: child.accountId
        )), childSeed)
        XCTAssertEqual(try keys.fetchKey(for: KeystoreTagV2.substrateSeedTagForMetaId(updated.metaId)), rootSeed)
        let reader = VerifiedMnemonicExportReader(keystore: keys)
        for (chain, account) in [(btcChain, originalBitcoin), (solChain, originalSolana)] {
            let exported = try reader.fetch(wallet: updated, info: ChainAccountInfo(chain: chain, account: account))
            XCTAssertEqual(exported.mnemonic.toString(), originalMnemonic)
            XCTAssertEqual(try provider.mnemonic(for: updated, chain: chain), originalMnemonic)
        }
        let afterBitcoin = try signedBitcoin(XCTUnwrap(provider.mnemonic(for: updated, chain: btcChain)))
        XCTAssertEqual(afterBitcoin.txHex, beforeBitcoin.txHex)
        XCTAssertEqual(afterBitcoin.txid, beforeBitcoin.txid)
        let message = Data("Public local child import continuity".utf8)
        let signed = try SolanaSigner.signMessage(mnemonic: XCTUnwrap(provider.mnemonic(for: updated, chain: solChain)), message: message)
        XCTAssertEqual(signed.publicKey, originalSolana.publicKey)
        XCTAssertTrue(try SolanaSigner.verifyMessage(
            publicKey: originalSolana.publicKey,
            message: message,
            signature: signed.signature
        ))
    }
}
