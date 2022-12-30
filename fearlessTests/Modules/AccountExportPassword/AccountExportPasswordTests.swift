import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import SoraFoundation
import Cuckoo

class AccountExportPasswordTests: XCTestCase {
    func testSuccessfullExport() throws {
        // given

        let facade = UserDataStorageTestFacade()
        let keychain = InMemoryKeychain()

        let accountsRepository = AccountRepositoryFactory.createRepository(for: facade)
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let view = MockAccountExportPasswordViewProtocol()
        let wireframe = MockAccountExportPasswordWireframeProtocol()

        let presenter = AccountExportPasswordPresenter(
            flow: .single(chain: ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: UInt16(0)), address: AddressTestConstants.kusamaAddress),
            localizationManager: LocalizationManager.shared)

        presenter.view = view
        presenter.wireframe = wireframe

        let exportWrapper = KeystoreExportWrapper(keystore: keychain)
        let interactor = AccountExportPasswordInteractor(exportJsonWrapper: exportWrapper,
                                                         accountRepository: AnyDataProviderRepository(accountsRepository),
                                                         operationManager: OperationManagerFacade.sharedManager,
                                                         extrinsicOperationFactory: ExtrinsicOperationFactoryStub(),
                                                         chainRepository: AnyDataProviderRepository(chainRepository))
        presenter.interactor = interactor
        interactor.presenter = presenter

        var inputViewModel: InputViewModelProtocol?
        var confirmationViewModel: InputViewModelProtocol?

        stub(view) { stub in
            when(stub).setPasswordInputViewModel(any()).then { viewModel in
                inputViewModel = viewModel
            }

            when(stub).setPasswordConfirmationViewModel(any()).then { viewModel in
                confirmationViewModel = viewModel
            }

            when(stub).set(error: any()).thenDoNothing()
        }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showJSONExport(any(), from: any()).then { _ in
                expectation.fulfill()
            }
            when(stub).present(message: any(), title: any(), closeAction: any(), from: any()).then { _ in
                XCTFail()
            }
        }

        // when

        presenter.setup()

        inputViewModel?.inputHandler.changeValue(to: Constants.validSrKeystorePassword)
        confirmationViewModel?.inputHandler.changeValue(to: Constants.validSrKeystorePassword)

        presenter.proceed()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
