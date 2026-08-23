import XCTest
@testable import fearless
import SoraKeystore
import Cuckoo
import IrohaCrypto
import RobinHood
import SoraFoundation

class AccountConfirmTests: XCTestCase {

    func testEventCenterRemovalFromObserverDeinitDoesNotRetainObserver() {
        let syncQueue = DispatchQueue(label: "co.jp.soramitsu.fearless.tests.event-center")
        let eventCenter = EventCenter(syncQueue: syncQueue)
        weak var weakObserver: DeinitRemovingEventVisitor?

        autoreleasepool {
            var observer: DeinitRemovingEventVisitor? = DeinitRemovingEventVisitor(eventCenter: eventCenter)
            weakObserver = observer
            eventCenter.add(observer: observer!, dispatchIn: .main)
            syncQueue.sync {}

            observer = nil
        }

        XCTAssertNil(weakObserver)
        syncQueue.sync {}
    }

    func testBitcoinChainMnemonicConfirmationCreatesPersistedSignableAccount() throws {
        let storageFacade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let keychain = InMemoryKeychain()
        let mnemonic = try IRMnemonicCreator().mnemonic(
            fromList: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: wallet.name,
            derivationPath: "",
            cryptoType: .sr25519,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId
        )
        let repository = AccountRepositoryFactory(storageFacade: storageFacade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        let eventCenter = MockEventCenterProtocol()
        let interactor = AccountConfirmInteractor(
            flow: .chain(request),
            accountOperationFactory: MetaAccountOperationFactory(keystore: keychain),
            accountRepository: AnyDataProviderRepository(repository),
            settings: settings,
            operationManager: OperationManager(),
            eventCenter: eventCenter
        )
        let presenter = MockAccountConfirmInteractorOutputProtocol()
        interactor.presenter = presenter
        let completion = expectation(description: "Bitcoin account persisted")
        completion.assertForOverFulfill = true
        var completionCount = 0
        var selectedAccountChangedCount = 0

        stub(presenter) { stub in
            when(stub.didCompleteConfirmation()).then {
                completionCount += 1
                completion.fulfill()
            }
            when(stub.didReceive(error: any(Error.self))).then { error in
                XCTFail("Unexpected Bitcoin account creation error: \(error)")
                completion.fulfill()
            }
        }
        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is SelectedAccountChanged {
                    selectedAccountChangedCount += 1
                }
            }
        }

        interactor.confirm(words: mnemonic.allWords())
        interactor.confirm(words: mnemonic.allWords())

        wait(for: [completion], timeout: 10)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(selectedAccountChangedCount, 1)
        let updatedWallet = try XCTUnwrap(settings.value)
        let bitcoinAccount = try XCTUnwrap(
            updatedWallet.chainAccounts.first(where: {
                UniversalWalletChainAccountSupport.isValidBitcoinAccount($0)
            })
        )

        XCTAssertTrue(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: bitcoinAccount.accountId
                )
            )
        )
        XCTAssertEqual(
            try KeychainUniversalWalletMnemonicProvider(keystore: keychain)
                .mnemonic(
                    for: updatedWallet,
                    chain: UniversalWalletRegistry.bitcoinMainnetChainModel
                ),
            mnemonic.toString()
        )
    }

    func testMnemonicConfirm() throws {
        // given

        let view = MockAccountConfirmViewProtocol()
        let wireframe = MockAccountConfirmWireframeProtocol()

        let storageFacade = UserDataStorageTestFacade()

        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        let keychain = InMemoryKeychain()

        let mnemonicWords = "great fog follow obtain oyster raw patient extend use mirror fix balance blame sudden vessel"

        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicWords)
        
        let newAccountRequest = MetaAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: "myusername",
            substrateDerivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)

        let repository = AccountRepositoryFactory(storageFacade: storageFacade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])

        let eventCenter = MockEventCenterProtocol()

        let flow: AccountConfirmFlow = .wallet(newAccountRequest)
        let interactor = AccountConfirmInteractor(flow: flow,
                                                  accountOperationFactory: accountOperationFactory,
                                                  accountRepository: AnyDataProviderRepository(repository),
                                                  settings: settings,
                                                  operationManager: OperationManager(),
                                                  eventCenter: eventCenter)

        let presenter = AccountConfirmPresenter(interactor: interactor,
                                                wireframe: wireframe,
                                                localizationManager: LocalizationManager.shared)
        interactor.presenter = presenter

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.controller.get).thenReturn(UIViewController())

            when(stub.didReceive(words: any([String].self), afterConfirmationFail: any(Bool.self))).then { _ in
                setupExpectation.fulfill()
            }
        }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.proceed(from: any(AccountConfirmViewProtocol?.self),
                               flow: any(AccountConfirmFlow?.self))).then { _ in
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

        presenter.didLoad(view: view)

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        presenter.confirm(words: mnemonic.allWords())

        // then

        wait(for: [expectation, completeExpectation], timeout: 10)

        guard let selectedAccount = settings.value else {
            XCTFail("Unexpected empty account")
            return
        }

        XCTAssertEqual(selectedAccount.name, newAccountRequest.username)

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

private final class DeinitRemovingEventVisitor: EventVisitorProtocol {
    private let eventCenter: EventCenterProtocol

    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter
    }

    deinit {
        eventCenter.remove(observer: self)
    }
}
