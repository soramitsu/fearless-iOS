import XCTest
@testable import fearless
import FearlessSecureStorage
import Cuckoo
import IrohaCrypto
import RobinHood
import FearlessFoundation

class AccountConfirmTests: XCTestCase {

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
