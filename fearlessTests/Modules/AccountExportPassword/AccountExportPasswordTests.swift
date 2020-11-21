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

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            keychain: keychain,
                                                            settings: settings)

        let givenAccount = settings.selectedAccount!

        let accountsRepository: CoreDataRepository<AccountItem, CDAccountItem> = facade.createRepository()
        let operation = accountsRepository.saveOperation({ [givenAccount]}, { [] })

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let view = MockAccountExportPasswordViewProtocol()
        let wireframe = MockAccountExportPasswordWireframeProtocol()

        let presenter = AccountExportPasswordPresenter(address: givenAccount.address,
                                                       localizationManager: LocalizationManager.shared)

        presenter.view = view
        presenter.wireframe = wireframe

        let exportWrapper = KeystoreExportWrapper(keystore: keychain)
        let interactor = AccountExportPasswordInteractor(exportJsonWrapper: exportWrapper,
                                                         repository: AnyDataProviderRepository(accountsRepository),
                                                         operationManager: OperationManagerFacade.sharedManager)
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
