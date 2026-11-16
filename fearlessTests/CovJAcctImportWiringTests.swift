import XCTest
import UIKit
import SSFModels
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
@testable import fearless

final class CovJAcctOperationFactoryStub: MetaAccountOperationFactoryProtocol {
    var mnemonicRequests: [MetaAccountImportMnemonicRequest] = []
    var seedRequests: [MetaAccountImportSeedRequest] = []
    var keystoreRequests: [MetaAccountImportKeystoreRequest] = []
    var chainMnemonicRequests: [ChainAccountImportMnemonicRequest] = []
    var chainSeedRequests: [ChainAccountImportSeedRequest] = []
    var chainKeystoreRequests: [ChainAccountImportKeystoreRequest] = []

    private func operation() -> BaseOperation<MetaAccountModel> {
        ClosureOperation { throw CovJError("not persisted in tests") }
    }

    func newMetaAccountOperation(request: MetaAccountImportMnemonicRequest, isBackuped _: Bool) -> BaseOperation<MetaAccountModel> {
        mnemonicRequests.append(request)
        return operation()
    }

    func newMetaAccountOperation(request: MetaAccountImportSeedRequest, isBackuped _: Bool) -> BaseOperation<MetaAccountModel> {
        seedRequests.append(request)
        return operation()
    }

    func newMetaAccountOperation(request: MetaAccountImportKeystoreRequest, isBackuped _: Bool) -> BaseOperation<MetaAccountModel> {
        keystoreRequests.append(request)
        return operation()
    }

    func importChainAccountOperation(request: ChainAccountImportMnemonicRequest) -> BaseOperation<MetaAccountModel> {
        chainMnemonicRequests.append(request)
        return operation()
    }

    func importChainAccountOperation(request: ChainAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        chainSeedRequests.append(request)
        return operation()
    }

    func importChainAccountOperation(request: ChainAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel> {
        chainKeystoreRequests.append(request)
        return operation()
    }
}

final class CovJAcctKeystoreServiceStub: KeystoreImportServiceProtocol {
    var definition: KeystoreDefinition?
    var observers: [KeystoreImportObserver] = []
    var clears = 0

    func handle(url _: URL) -> Bool { false }
    func add(observer: KeystoreImportObserver) { observers.append(observer) }
    func remove(observer: KeystoreImportObserver) { observers.removeAll { $0 === observer } }
    func clear() {
        clears += 1
        definition = nil
    }
}

final class CovJAcctImportOutputSpy: AccountImportInteractorOutputProtocol {
    var metadata: [MetaAccountImportMetadata] = []
    var completions = 0
    var errors: [Error] = []
    var suggestions: [(String, MetaAccountImportPreferredInfo?)] = []
    var keystoreFailures = 0

    func didReceiveAccountImport(metadata: MetaAccountImportMetadata) { self.metadata.append(metadata) }
    func didCompleteAccountImport() { completions += 1 }
    func didReceiveAccountImport(error: Error) { errors.append(error) }
    func didSuggestKeystore(text: String, preferredInfo: MetaAccountImportPreferredInfo?) { suggestions.append((text, preferredInfo)) }
    func didFailToDeriveMetadataFromKeystore() { keystoreFailures += 1 }
}

final class CovJAcctFundsProbeStub: UniversalWalletFundsProbing {
    var secrets: [UniversalWalletSecret] = []

    func funds(of secret: UniversalWalletSecret, slots: Set<UniversalWalletSlot>) async -> [UniversalWalletSlot: UniversalWalletFundsReading] {
        await MainActor.run { secrets.append(secret) }
        return Dictionary(uniqueKeysWithValues: slots.map { ($0, UniversalWalletFundsReading(state: .empty)) })
    }
}

enum CovJAcctKeystoreFixture {
    static let substrate = """
    {"address":"FMN7zMySGxiWrDuPDkf1jrGoF9szj9igADV8V9pXUwbzDwB","encoded":"AAAA",\
    "encoding":{"content":["pkcs8","sr25519"],"type":["scrypt","xsalsa20-poly1305"],"version":"3"},\
    "meta":{"genesisHash":"0xb0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe","name":"Test5","tags":[],"whenCreated":1}}
    """

    static let unsupported = """
    {"address":"FMN7zMySGxiWrDuPDkf1jrGoF9szj9igADV8V9pXUwbzDwB","encoded":"AAAA",\
    "encoding":{"content":["pkcs8","unknown"],"type":["scrypt","xsalsa20-poly1305"],"version":"3"},"meta":{"name":"Odd"}}
    """

    static func definition(_ json: String) throws -> KeystoreDefinition {
        try JSONDecoder().decode(KeystoreDefinition.self, from: Data(json.utf8))
    }
}

final class CovJAcctBaseImportInteractorTests: XCTestCase {
    private func makeInteractor(
        source: AccountImportSource = .seed
    ) -> (BaseAccountImportInteractor, CovJAcctOperationFactoryStub, CovJAcctKeystoreServiceStub, CovJAcctImportOutputSpy) {
        let factory = CovJAcctOperationFactoryStub()
        let keystore = CovJAcctKeystoreServiceStub()
        let output = CovJAcctImportOutputSpy()
        let interactor = BaseAccountImportInteractor(
            accountOperationFactory: factory,
            accountRepository: AnyDataProviderRepository(CovJMemoryRepository<MetaAccountModel>()),
            operationManager: OperationManager(),
            keystoreImportService: keystore,
            defaultSource: source
        )
        interactor.presenter = output
        return (interactor, factory, keystore, output)
    }

    func testSetupProvidesMetadataAndSuggestsPendingKeystore() throws {
        let (interactor, _, keystore, output) = makeInteractor(source: .keystore)
        keystore.definition = try CovJAcctKeystoreFixture.definition(CovJAcctKeystoreFixture.substrate)

        interactor.setup()

        XCTAssertEqual(output.metadata.first?.defaultSource, .keystore)
        XCTAssertEqual(output.metadata.first?.availableSources, AccountImportSource.allCases)
        XCTAssertEqual(output.metadata.first?.defaultCryptoType, .sr25519)
        XCTAssertEqual(keystore.observers.count, 1)
        XCTAssertEqual(keystore.clears, 1)
        let suggestion = try XCTUnwrap(output.suggestions.first)
        XCTAssertTrue(suggestion.0.contains("FMN7zMySGxiWrDuPDkf1jrGoF9szj9igADV8V9pXUwbzDwB"))
        XCTAssertEqual(suggestion.1?.username, "Test5")
        XCTAssertEqual(suggestion.1?.cryptoType, .sr25519)
        XCTAssertEqual(suggestion.1?.isEthereum, false)
    }

    func testDefinitionUpdatesReportUnsupportedKeystoresAndIgnoreEmptyOnes() throws {
        let (interactor, _, keystore, output) = makeInteractor()
        interactor.setup()
        XCTAssertTrue(output.suggestions.isEmpty)
        XCTAssertEqual(keystore.clears, 0)

        keystore.definition = try CovJAcctKeystoreFixture.definition(CovJAcctKeystoreFixture.unsupported)
        interactor.didUpdateDefinition(from: nil)

        XCTAssertEqual(keystore.clears, 1)
        XCTAssertTrue(output.suggestions.isEmpty)
        XCTAssertEqual(output.errors.count, 1)
        interactor.didUpdateDefinition(from: nil)
        XCTAssertEqual(output.errors.count, 1)
    }

    func testDeriveMetadataFromKeystoreText() {
        let (interactor, _, _, output) = makeInteractor()

        interactor.deriveMetadataFromKeystore(CovJAcctKeystoreFixture.substrate)
        interactor.deriveMetadataFromKeystore("not json")
        interactor.deriveMetadataFromKeystore(CovJAcctKeystoreFixture.unsupported)

        XCTAssertEqual(output.suggestions.count, 1)
        XCTAssertEqual(output.suggestions.first?.0, CovJAcctKeystoreFixture.substrate)
        XCTAssertEqual(output.keystoreFailures, 2)
        XCTAssertNotNil(interactor.createMnemonicFromString(CovJAcctImportHarness.phrase))
        XCTAssertNil(interactor.createMnemonicFromString("not a phrase"))
    }

    func testMetaAccountRequestsAreMappedForEverySource() throws {
        let (interactor, factory, _, _) = makeInteractor()
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: CovJAcctImportHarness.phrase)
        let mnemonicData = MetaAccountImportRequestSource.MnemonicImportRequestData(
            mnemonic: mnemonic, substrateDerivationPath: "//1", ethereumDerivationPath: "//44//60//0/0/0", substratePasswordRule: .nfc
        )
        interactor.importMetaAccount(request: MetaAccountImportRequest(
            source: .mnemonic(data: mnemonicData), username: "Words", cryptoType: .ed25519, defaultChainId: "chain"
        ))
        let seedData = MetaAccountImportRequestSource.SeedImportRequestData(
            substrateSeed: "0x01", ethereumSeed: "0x02", substrateDerivationPath: "//2", ethereumDerivationPath: "//3"
        )
        interactor.importMetaAccount(request: MetaAccountImportRequest(
            source: .seed(data: seedData), username: "Seed", cryptoType: .sr25519, defaultChainId: nil
        ))
        let keystoreData = MetaAccountImportRequestSource.KeystoreImportRequestData(
            substrateKeystore: "{}", ethereumKeystore: "{\"e\":1}", substratePassword: "a", ethereumPassword: "b"
        )
        interactor.importMetaAccount(request: MetaAccountImportRequest(
            source: .keystore(data: keystoreData), username: "Json", cryptoType: .ecdsa, defaultChainId: nil
        ))

        let words = try XCTUnwrap(factory.mnemonicRequests.first)
        XCTAssertEqual(words.username, "Words")
        XCTAssertEqual(words.cryptoType, .ed25519)
        XCTAssertEqual(words.defaultChainId, "chain")
        XCTAssertEqual(words.substratePasswordRule, .nfc)
        XCTAssertEqual(words.universalWalletEnrollment, .unchecked)
        let seed = try XCTUnwrap(factory.seedRequests.first)
        XCTAssertEqual([seed.substrateSeed, seed.ethereumSeed, seed.substrateDerivationPath, seed.ethereumDerivationPath], ["0x01", "0x02", "//2", "//3"])
        XCTAssertEqual(seed.username, "Seed")
        let keystore = try XCTUnwrap(factory.keystoreRequests.first)
        XCTAssertEqual([keystore.substrateKeystore, keystore.ethereumKeystore, keystore.substratePassword, keystore.ethereumPassword],
                       ["{}", "{\"e\":1}", "a", "b"])
        XCTAssertEqual(keystore.cryptoType, .ecdsa)
    }

    func testPasswordProtectedWordsAreProbedBeforeImport() throws {
        let (interactor, factory, _, _) = makeInteractor()
        let probe = CovJAcctFundsProbeStub()
        interactor.universalWalletFundsProbe = probe
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: CovJAcctImportHarness.phrase)
        let data = MetaAccountImportRequestSource.MnemonicImportRequestData(
            mnemonic: mnemonic, substrateDerivationPath: "//1///secret", ethereumDerivationPath: ""
        )

        interactor.importMetaAccount(request: MetaAccountImportRequest(
            source: .mnemonic(data: data), username: "Guarded", cryptoType: .sr25519, defaultChainId: nil
        ))

        XCTAssertTrue(factory.mnemonicRequests.isEmpty)
        XCTAssertTrue(CovJWait.until { !factory.mnemonicRequests.isEmpty })
        XCTAssertEqual(probe.secrets, [UniversalWalletSecret(mnemonic: CovJAcctImportHarness.phrase, passphrase: "")])
        let request = try XCTUnwrap(factory.mnemonicRequests.first)
        XCTAssertEqual(request.universalWalletEnrollment, .imported(keepingNoPassword: []))
        XCTAssertEqual(request.universalWalletPassphrase, "secret")
    }

    func testChainRequestsCarryNetworkAndWallet() throws {
        let (interactor, factory, _, _) = makeInteractor()
        let wallet = AccountGenerator.generateMetaAccount()
        let substrate = CovJFixture.chain(name: "Kusama", addressPrefix: 2)
        let ethereum = CovJFixture.chain(name: "Moonbeam", options: [.ethereumBased])
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: CovJAcctImportHarness.phrase)

        interactor.importUniqueChain(request: UniqueChainImportRequest(
            source: .mnemonic(data: .init(mnemonic: mnemonic, derivationPath: "//5", substratePasswordRule: .asTyped)),
            username: "A", cryptoType: .sr25519, meta: wallet, chain: substrate
        ))
        interactor.importUniqueChain(request: UniqueChainImportRequest(
            source: .seed(data: .init(seed: "0xbeef", derivationPath: "//6")), username: "B", cryptoType: .ecdsa, meta: wallet, chain: ethereum
        ))
        interactor.importUniqueChain(request: UniqueChainImportRequest(
            source: .keystore(data: .init(keystore: "{}", password: "pw")), username: "C", cryptoType: .ed25519, meta: wallet, chain: substrate
        ))

        let words = try XCTUnwrap(factory.chainMnemonicRequests.first)
        XCTAssertEqual(words.chainId, substrate.chainId)
        XCTAssertFalse(words.isEthereum)
        XCTAssertEqual(words.derivationPath, "//5")
        XCTAssertEqual(words.substratePasswordRule, .asTyped)
        XCTAssertEqual(words.meta.metaId, wallet.metaId)
        let seed = try XCTUnwrap(factory.chainSeedRequests.first)
        XCTAssertEqual(seed.chainId, ethereum.chainId)
        XCTAssertTrue(seed.isEthereum)
        XCTAssertEqual(seed.seed, "0xbeef")
        XCTAssertEqual(seed.username, "B")
        let keystore = try XCTUnwrap(factory.chainKeystoreRequests.first)
        XCTAssertEqual(keystore.keystore, "{}")
        XCTAssertEqual(keystore.password, "pw")
        XCTAssertEqual(keystore.cryptoType, .ed25519)
    }

    func testJsonFactoryAndNumberProcessor() throws {
        let info = try AccountImportJsonFactory().createInfo(from: CovJAcctKeystoreFixture.definition(CovJAcctKeystoreFixture.substrate))
        XCTAssertEqual(info.username, "Test5")
        XCTAssertEqual(info.cryptoType, .sr25519)
        XCTAssertEqual(info.isEthereum, false)
        XCTAssertThrowsError(try AccountImportJsonFactory().createInfo(
            from: CovJAcctKeystoreFixture.definition(CovJAcctKeystoreFixture.unsupported)
        ))
        XCTAssertEqual(NumbersAndSlashesProcessor().process(text: "//44a//6x0/b0"), "//44//60/0")
        XCTAssertEqual(NumbersAndSlashesProcessor().process(text: "abc"), "")
    }
}
