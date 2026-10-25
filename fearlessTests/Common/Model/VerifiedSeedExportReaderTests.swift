import XCTest
@testable import fearless
import IrohaCrypto
import RobinHood
import SoraKeystore
import SoraFoundation
import SSFModels

/// IK-11 (d): a raw seed is shown for export only when importing it recreates the account
/// it is shown for. The 4.0.x releases stored a per-chain account's seed under the
/// wallet-level tag, replacing the wallet's own seed; these tests rebuild that layout with
/// the app's own import code and check what export shows.
final class VerifiedSeedExportReaderTests: XCTestCase {
    private let walletPhrase = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
    private let chainPhrase = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private let walletRawSeed = "0x" + String(repeating: "1f", count: 32)
    private let chainRawSeed = "0x" + String(repeating: "2e", count: 32)
    private let ethereumRawSeed = "0x" + String(repeating: "3c", count: 32)
    private let chainId = ChainAccountRecordsFixture.polkadotChainId

    func testHealthyMnemonicWallet_whenExported_thenStoredSeedIsShownWithItsPath() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, path: "//fearless", keystore: keystore)
        let storedSeed = try keystore.fetchKey(for: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))

        let export = try reader(keystore).fetchSeed(
            metaId: wallet.metaId, accountId: nil, publicKey: try XCTUnwrap(wallet.substratePublicKey),
            cryptoType: .sr25519, ethereumBased: false
        )

        XCTAssertEqual(export, VerifiedSeedExport(seed: storedSeed, derivationPath: "//fearless"))
    }

    func testWalletSeedReplacedBy40xChainImport_whenWalletIsExported_thenItsOwnSeedIsRebuiltFromItsPhrase() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, path: "", keystore: keystore)
        let walletSeed = try keystore.fetchKey(for: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))
        let chainAccount = try importChainAccountAs40x(phrase: chainPhrase, into: wallet, keystore: keystore)
        let replacedSeed = try keystore.fetchKey(for: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))
        XCTAssertNotEqual(replacedSeed, walletSeed, "4.0.x layout: the wallet-level seed now belongs to the chain account")

        let export = try reader(keystore).fetchSeed(
            metaId: wallet.metaId, accountId: nil, publicKey: try XCTUnwrap(wallet.substratePublicKey),
            cryptoType: .sr25519, ethereumBased: false
        )

        XCTAssertEqual(export.seed, walletSeed)
        XCTAssertNotEqual(export.seed, replacedSeed)
        XCTAssertEqual(
            try reader(keystore).fetchSeed(
                metaId: wallet.metaId, accountId: chainAccount.accountId, publicKey: chainAccount.publicKey,
                cryptoType: .sr25519, ethereumBased: false
            ).seed,
            replacedSeed
        )
    }

    func testRawSeedChainAccountImportedBy40x_whenExported_thenWalletLevelSeedIsShownBecauseItRecreatesIt() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, path: "", keystore: keystore)
        let chainAccount = try importChainAccountAs40x(rawSeed: chainRawSeed, into: wallet, keystore: keystore)

        let export = try reader(keystore).fetchSeed(
            metaId: wallet.metaId, accountId: chainAccount.accountId, publicKey: chainAccount.publicKey,
            cryptoType: .sr25519, ethereumBased: false
        )

        XCTAssertEqual(export.seed, try Data(hexStringSSF: chainRawSeed))
    }

    func testRawSeedWalletWhoseSeedWasReplaced_whenExported_thenNothingIsShownAndTheMismatchIsReported() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(rawSeed: walletRawSeed, keystore: keystore)
        _ = try importChainAccountAs40x(rawSeed: chainRawSeed, into: wallet, keystore: keystore)

        XCTAssertThrowsError(
            try reader(keystore).fetchSeed(
                metaId: wallet.metaId, accountId: nil, publicKey: try XCTUnwrap(wallet.substratePublicKey),
                cryptoType: .sr25519, ethereumBased: false
            )
        ) { error in
            XCTAssertEqual(error as? VerifiedSeedExportError, .seedDoesNotMatchAccount)
        }
    }

    func testRawSeedWallet_whenExported_thenTheImportedSeedIsShown() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(rawSeed: walletRawSeed, keystore: keystore)

        let export = try reader(keystore).fetchSeed(
            metaId: wallet.metaId, accountId: nil, publicKey: try XCTUnwrap(wallet.substratePublicKey),
            cryptoType: .sr25519, ethereumBased: false
        )

        XCTAssertEqual(export.seed, try Data(hexStringSSF: walletRawSeed))
    }

    func testAccountWithoutAnyStoredSeed_whenExported_thenMissingSeedIsReported() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, path: "", keystore: keystore)
        // A wallet imported from a JSON file stores only its secret key.
        try keystore.deleteKey(for: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))
        try keystore.deleteKey(for: fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId))

        XCTAssertThrowsError(
            try reader(keystore).fetchSeed(
                metaId: wallet.metaId, accountId: nil, publicKey: try XCTUnwrap(wallet.substratePublicKey),
                cryptoType: .sr25519, ethereumBased: false
            )
        ) { error in
            XCTAssertEqual(error as? VerifiedSeedExportError, .missingSeed)
        }
    }

    func testEd25519AccountWithoutSeed_whenExported_thenItsSecretKeyIsShownWithoutPath() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, path: "//hard", cryptoType: .ed25519, keystore: keystore)
        try keystore.deleteKey(for: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))
        try keystore.deleteKey(for: fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        let secretKey = try keystore.fetchKey(for: fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId))

        let export = try reader(keystore).fetchSeed(
            metaId: wallet.metaId, accountId: nil, publicKey: try XCTUnwrap(wallet.substratePublicKey),
            cryptoType: .ed25519, ethereumBased: false
        )

        XCTAssertEqual(export, VerifiedSeedExport(seed: secretKey, derivationPath: nil))
    }

    func testEthereumAccount_whenSecretKeyMatches_thenItIsShownAndOtherwiseNot() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, path: "", keystore: keystore)
        let publicKey = try XCTUnwrap(wallet.ethereumPublicKey)
        let secretKeyTag = fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId)
        let secretKey = try keystore.fetchKey(for: secretKeyTag)

        XCTAssertEqual(
            try reader(keystore).fetchSeed(
                metaId: wallet.metaId, accountId: nil, publicKey: publicKey, cryptoType: .ecdsa, ethereumBased: true
            ),
            VerifiedSeedExport(seed: secretKey, derivationPath: nil)
        )

        try keystore.saveKey(Data(repeating: 0x42, count: 32), with: secretKeyTag)
        XCTAssertThrowsError(
            try reader(keystore).fetchSeed(
                metaId: wallet.metaId, accountId: nil, publicKey: publicKey, cryptoType: .ecdsa, ethereumBased: true
            )
        ) { error in
            XCTAssertEqual(error as? VerifiedSeedExportError, .seedDoesNotMatchAccount)
        }
    }

    func testExportOptions_whenChainAccountSeedIsOnlyUnderTheWalletTag_thenRawSeedIsOfferedOnlyIfItMatches() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, path: "", keystore: keystore)
        let chainAccount = try importChainAccountAs40x(rawSeed: chainRawSeed, into: wallet, keystore: keystore)
        let walletWithAccount = wallet.replacingChainAccounts([chainAccount])
        let provider = AvailableExportOptionsProvider(keystore: keystore)

        XCTAssertTrue(
            provider.getAvailableExportOptions(
                for: walletWithAccount, accountId: chainAccount.accountId, isEthereum: false
            ).contains(.seed)
        )

        // A per-chain account imported from a JSON file has no seed of its own; the
        // wallet-level seed belongs to another account, so the option is not offered.
        let jsonAccount = ChainAccountRecordsFixture.substrateAccount(chainId: "json-chain", marker: 0x77)
        XCTAssertFalse(
            provider.getAvailableExportOptions(
                for: wallet.replacingChainAccounts([jsonAccount]), accountId: jsonAccount.accountId, isEthereum: false
            ).contains(.seed)
        )
        XCTAssertTrue(
            provider.getAvailableExportOptions(
                for: wallet.replacingChainAccounts([jsonAccount]), accountId: jsonAccount.accountId, isEthereum: false
            ).contains(.keystore)
        )
    }

    func testWalletExport_whenSomeSeedsCannotBeVerified_thenOnlyVerifiedSeedsAreListedAndTheRestReported() {
        let shown = Data(repeating: 0x0A, count: 32)
        let output = recordWalletExport(
            seeds: [Data(repeating: 1, count: 32): .success(VerifiedSeedExport(seed: shown, derivationPath: "//1")),
                    Data(repeating: 2, count: 32): .failure(VerifiedSeedExportError.seedDoesNotMatchAccount)]
        )

        XCTAssertEqual(output.exportData?.map(\.seed), [shown])
        XCTAssertEqual(output.notShown?.map(\.chain.chainId), [Data(repeating: 2, count: 32).toHex()])
        XCTAssertEqual(output.notShown?.first?.error as? VerifiedSeedExportError, .seedDoesNotMatchAccount)
        XCTAssertNil(output.error)
    }

    /// Codex #5: a 4.0.x per-chain raw-seed import replaced a raw-seed wallet's own Substrate
    /// seed (the layout `importChainAccountAs40x` rebuilds). The export can show the Ethereum
    /// seed only. Copying it must not mark the wallet backed up, and the Substrate account is
    /// named with a JSON export that does back it up.
    func testRawSeedWalletWhoseSubstrateSeedWasReplaced_whenOnlyEthereumIsCopied_thenItIsNotMarkedBackedUp() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(rawSeed: walletRawSeed, ethereumSeed: ethereumRawSeed, keystore: keystore)
        _ = try importChainAccountAs40x(rawSeed: chainRawSeed, into: wallet, keystore: keystore)
        let polkadot = ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.polkadotChainId)
        let moonbeam = ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.moonbeamChainId, ethereumBased: true)
        let accounts = try [polkadot, moonbeam].map { chain in
            ChainAccountInfo(chain: chain, account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
        }
        let flow = ExportFlow.multiple(wallet: wallet, accounts: accounts)

        let output = recordWalletExport(reader: reader(keystore), wallet: wallet, accounts: flow.exportingAccounts)
        let screen = SeedExportScreen(flow: flow)
        screen.presenter.didLoadView()
        screen.presenter.didReceive(exportData: try XCTUnwrap(output.exportData), notShown: try XCTUnwrap(output.notShown))

        XCTAssertEqual(output.exportData?.map(\.chain.chainId), [moonbeam.chainId])
        XCTAssertEqual(output.notShown?.map(\.chain.chainId), [polkadot.chainId])
        XCTAssertEqual(screen.wireframe.sheets.count, 1, "the notice waits for the export warning to close")

        try XCTUnwrap(screen.wireframe.sheets.first?.dismissCompletion)()
        let notice = try XCTUnwrap(screen.wireframe.sheets.last)
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        XCTAssertEqual(screen.wireframe.sheets.count, 2)
        XCTAssertEqual(notice.title, R.string.localizable.exportSeedUnavailableTitle(preferredLanguages: languages))
        XCTAssertEqual(
            notice.message,
            R.string.localizable.exportSeedPartialMessage(polkadot.name, preferredLanguages: languages)
        )

        screen.presenter.share(try XCTUnwrap(output.exportData?.first).seed.toHex(includePrefix: true))
        XCTAssertEqual(screen.wireframe.shares, 1)
        XCTAssertEqual(screen.interactor.backups, 0, "a backup without the Substrate key is no backup")

        notice.actions.first?.handler?()
        XCTAssertEqual(screen.wireframe.jsonExports, 1)
    }

    func testWalletExport_whenEverySeedIsShownAndCopied_thenTheWalletIsMarkedBackedUpOnce() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(rawSeed: walletRawSeed, ethereumSeed: ethereumRawSeed, keystore: keystore)
        let accounts = try [
            ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.polkadotChainId),
            ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.moonbeamChainId, ethereumBased: true)
        ].map { chain in
            ChainAccountInfo(chain: chain, account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
        }
        let flow = ExportFlow.multiple(wallet: wallet, accounts: accounts)

        let output = recordWalletExport(reader: reader(keystore), wallet: wallet, accounts: flow.exportingAccounts)
        let screen = SeedExportScreen(flow: flow)
        screen.presenter.didLoadView()
        screen.presenter.didReceive(exportData: try XCTUnwrap(output.exportData), notShown: try XCTUnwrap(output.notShown))
        try XCTUnwrap(screen.wireframe.sheets.first?.dismissCompletion)()

        XCTAssertEqual(output.notShown?.count, 0)
        XCTAssertEqual(screen.wireframe.sheets.count, 1, "no notice when every seed is shown")
        for seed in try XCTUnwrap(output.exportData) {
            screen.presenter.share(seed.seed.toHex(includePrefix: true))
        }
        XCTAssertEqual(screen.interactor.backups, 1)
    }

    func testWalletExport_whenNoSeedCanBeShown_thenTheReasonIsShownInsteadOfAnEmptyScreen() {
        let output = recordWalletExport(
            seeds: [Data(repeating: 1, count: 32): .failure(VerifiedSeedExportError.seedDoesNotMatchAccount)]
        )

        XCTAssertNil(output.exportData)
        XCTAssertEqual(output.error as? VerifiedSeedExportError, .seedDoesNotMatchAccount)
    }

    func testReader_whenItRejectsOrShowsASeed_thenItNeverWritesOrRemovesKeys() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, path: "", keystore: keystore)
        let chainAccount = try importChainAccountAs40x(rawSeed: chainRawSeed, into: wallet, keystore: keystore)
        let probe = WriteRejectingKeystore(keystore)

        _ = try VerifiedSeedExportReader(keystore: probe).fetchSeed(
            metaId: wallet.metaId, accountId: nil, publicKey: try XCTUnwrap(wallet.substratePublicKey),
            cryptoType: .sr25519, ethereumBased: false
        )
        _ = try VerifiedSeedExportReader(keystore: probe).fetchSeed(
            metaId: wallet.metaId, accountId: chainAccount.accountId, publicKey: chainAccount.publicKey,
            cryptoType: .sr25519, ethereumBased: false
        )
        XCTAssertThrowsError(
            try VerifiedSeedExportReader(keystore: probe).fetchSeed(
                metaId: wallet.metaId, accountId: nil, publicKey: Data(repeating: 0x01, count: 32),
                cryptoType: .sr25519, ethereumBased: false
            )
        )

        XCTAssertEqual(probe.writeAttempts, 0)
    }
}

// MARK: - Helpers

private extension VerifiedSeedExportReaderTests {
    func reader(_ keystore: KeystoreProtocol) -> VerifiedSeedExportReader {
        VerifiedSeedExportReader(keystore: keystore)
    }

    func importWallet(
        phrase: String,
        path: String,
        cryptoType: CryptoType = .sr25519,
        keystore: KeystoreProtocol
    ) throws -> MetaAccountModel {
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: phrase),
            username: "Wallet",
            substrateDerivationPath: path,
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: cryptoType,
            defaultChainId: nil
        )
        return try run(MetaAccountOperationFactory(keystore: keystore).newMetaAccountOperation(
            request: request, isBackuped: true
        ))
    }

    func importWallet(rawSeed: String, ethereumSeed: String? = nil, keystore: KeystoreProtocol) throws -> MetaAccountModel {
        let request = MetaAccountImportSeedRequest(
            substrateSeed: rawSeed,
            ethereumSeed: ethereumSeed,
            username: "Raw seed wallet",
            substrateDerivationPath: "",
            ethereumDerivationPath: ethereumSeed == nil ? nil : DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519
        )
        return try run(MetaAccountOperationFactory(keystore: keystore).newMetaAccountOperation(
            request: request, isBackuped: true
        ))
    }

    /// Imports a per-chain account with the app's own code, then leaves its seed where 4.0.x
    /// left it: under the wallet-level tag only (fearless-iOS tag 4.0.4,
    /// `MetaAccountOperationFactory.importChainAccountOperation` calls `saveSeed` without an
    /// account id; secret key, path and entropy keep the account id).
    func importChainAccountAs40x(
        phrase: String? = nil,
        rawSeed: String? = nil,
        into wallet: MetaAccountModel,
        keystore: KeystoreProtocol
    ) throws -> ChainAccountModel {
        let factory = MetaAccountOperationFactory(keystore: keystore)
        let updatedWallet: MetaAccountModel
        if let phrase {
            updatedWallet = try run(factory.importChainAccountOperation(request: ChainAccountImportMnemonicRequest(
                mnemonic: try IRMnemonicCreator().mnemonic(fromList: phrase),
                username: wallet.name, derivationPath: "", cryptoType: .sr25519,
                isEthereum: false, meta: wallet, chainId: chainId
            )))
        } else {
            updatedWallet = try run(factory.importChainAccountOperation(request: ChainAccountImportSeedRequest(
                seed: try XCTUnwrap(rawSeed), username: wallet.name, derivationPath: "", cryptoType: .sr25519,
                isEthereum: false, meta: wallet, chainId: chainId
            )))
        }
        let chainAccount = try XCTUnwrap(updatedWallet.chainAccounts.first { $0.chainId == chainId })

        let accountTag = fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: chainAccount.accountId)
        let seed = try keystore.fetchKey(for: accountTag)
        try keystore.saveKey(seed, with: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))
        try keystore.deleteKey(for: accountTag)

        return chainAccount
    }

    /// Runs `ExportSeedInteractor.fetchExportDataForWallet` over one account per public key,
    /// with the reader's answer for each key fixed by `seeds`.
    func recordWalletExport(seeds: [Data: Result<VerifiedSeedExport, Error>]) -> RecordingExportSeedOutput {
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let accounts = seeds.keys.sorted { $0.toHex() < $1.toHex() }.map { publicKey in
            ChainAccountInfo(
                chain: ChainAccountRecordsFixture.chain(id: publicKey.toHex()),
                account: ChainAccountResponse(
                    chainId: publicKey.toHex(), accountId: publicKey, publicKey: publicKey, name: wallet.name,
                    cryptoType: .sr25519, addressPrefix: 0, isEthereumBased: false, isChainAccount: true,
                    walletId: wallet.metaId
                )
            )
        }
        return recordWalletExport(reader: StubSeedReader(results: seeds), wallet: wallet, accounts: accounts)
    }

    func recordWalletExport(
        reader: VerifiedSeedExportReading,
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo]
    ) -> RecordingExportSeedOutput {
        let interactor = ExportSeedInteractor(
            seedReader: reader,
            backupMarker: WalletBackupMarkerStore(storageFacade: UserDataStorageTestFacade()),
            operationManager: OperationManager(),
            chainRepository: AnyDataProviderRepository(
                SubstrateStorageTestFacade().createRepository(
                    filter: nil, sortDescriptors: [], mapper: AnyCoreDataMapper(ChainModelMapper())
                )
            ),
            eventCenter: MockEventCenterProtocol()
        )
        let output = RecordingExportSeedOutput(expectation: expectation(description: "export result"))
        interactor.presenter = output

        interactor.fetchExportDataForWallet(wallet, accounts: accounts)
        wait(for: [output.expectation], timeout: 10)
        return output
    }

    func run(_ operation: BaseOperation<MetaAccountModel>) throws -> MetaAccountModel {
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        (operation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        return result
    }
}

/// Forwards reads and counts every attempt to write or delete.
private final class WriteRejectingKeystore: KeystoreProtocol {
    private let base: KeystoreProtocol
    private(set) var writeAttempts = 0

    init(_ base: KeystoreProtocol) {
        self.base = base
    }

    func addKey(_: Data, with _: String) throws {
        writeAttempts += 1
        throw KeystoreError.unexpectedFail
    }

    func updateKey(_: Data, with _: String) throws {
        writeAttempts += 1
        throw KeystoreError.unexpectedFail
    }

    func fetchKey(for identifier: String) throws -> Data {
        try base.fetchKey(for: identifier)
    }

    func checkKey(for identifier: String) throws -> Bool {
        try base.checkKey(for: identifier)
    }

    func deleteKey(for _: String) throws {
        writeAttempts += 1
        throw KeystoreError.unexpectedFail
    }
}

private final class StubSeedReader: VerifiedSeedExportReading {
    private let results: [Data: Result<VerifiedSeedExport, Error>]

    init(results: [Data: Result<VerifiedSeedExport, Error>]) {
        self.results = results
    }

    func fetchSeed(
        metaId _: MetaAccountId,
        accountId _: AccountId?,
        publicKey: Data,
        cryptoType _: CryptoType,
        ethereumBased _: Bool
    ) throws -> VerifiedSeedExport {
        guard let result = results[publicKey] else {
            throw VerifiedSeedExportError.missingSeed
        }
        return try result.get()
    }
}

private final class RecordingExportSeedOutput: ExportSeedInteractorOutputProtocol {
    let expectation: XCTestExpectation
    private(set) var exportData: [ExportSeedData]?
    private(set) var notShown: [ExportSeedNotShown]?
    private(set) var error: Error?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func didReceive(exportData: [ExportSeedData], notShown: [ExportSeedNotShown]) {
        self.exportData = exportData
        self.notShown = notShown
        expectation.fulfill()
    }

    func didReceive(error: Error) {
        self.error = error
        expectation.fulfill()
    }
}

/// The seed export screen's presenter with recording doubles.
private final class SeedExportScreen {
    let presenter: ExportSeedPresenter
    let wireframe = ExportSeedWireframeStub()
    let interactor = ExportSeedInteractorSpy()

    init(flow: ExportFlow) {
        presenter = ExportSeedPresenter(flow: flow, localizationManager: LocalizationManager.shared)
        presenter.wireframe = wireframe
        presenter.interactor = interactor
    }
}

private final class ExportSeedInteractorSpy: ExportSeedInteractorInputProtocol {
    private(set) var backups = 0

    func fetchExportDataForAddress(_: String, chain _: ChainModel, wallet _: MetaAccountModel) {}
    func fetchExportDataForWallet(_: MetaAccountModel, accounts _: [ChainAccountInfo]) {}

    func didBackupSeed(wallet _: MetaAccountModel, completion: @escaping (Result<Void, Error>) -> Void) {
        backups += 1
        completion(.success(()))
    }
}

private final class ExportSeedWireframeStub: ExportSeedWireframeProtocol {
    private(set) var sheets: [SheetAlertPresentableViewModel] = []
    private(set) var shares = 0
    private(set) var jsonExports = 0

    func back(view _: ExportGenericViewProtocol?) {}

    func showJsonExport(flow _: ExportFlow, from _: ExportGenericViewProtocol?) {
        jsonExports += 1
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append(viewModel)
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func share(
        source _: UIActivityItemSource,
        from _: ControllerBackedProtocol?,
        with completionHandler: SharingCompletionHandler?
    ) {
        shares += 1
        completionHandler?(true)
    }
}
