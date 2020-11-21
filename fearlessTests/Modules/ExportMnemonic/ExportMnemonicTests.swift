import XCTest
@testable import fearless
import SoraKeystore
import SoraFoundation
import RobinHood
import Cuckoo

class ExportMnemonicTests: XCTestCase {
    func testSuccessfullExport() throws {
        // given

        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        let storageFacade = UserDataStorageTestFacade()
        let repository: CoreDataRepository<AccountItem, CDAccountItem> = storageFacade.createRepository()

        let derivationPath = "//some//work"

        try AccountCreationHelper
            .createAccountFromMnemonic(cryptoType: .sr25519,
                                       networkType: .kusama,
                                       derivationPath: derivationPath,
                                       keychain: keychain,
                                       settings: settings)

        let givenAccount = settings.selectedAccount!

        let saveOperation = repository.saveOperation({ [givenAccount] }, { [] })

        OperationQueue().addOperation(saveOperation)

        // when

        let view = MockExportGenericViewProtocol()

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).set(viewModel: any()).then { _ in
                setupExpectation.fulfill()
            }
        }

        let wireframe = MockExportMnemonicWireframeProtocol()

        let sharingExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).present(viewModel: any(), style: any(), from: any()).then { (viewModel, _, _) in
                viewModel.actions.first?.handler?()
            }

            when(stub).share(source: any(), from: any(), with: any()).then { _ in
                sharingExpectation.fulfill()
            }
        }

        let presenter = ExportMnemonicPresenter(address: givenAccount.address,
                                                localizationManager: LocalizationManager.shared)

        let interactor = ExportMnemonicInteractor(keystore: keychain,
                                                  repository: AnyDataProviderRepository(repository),
                                                  operationManager: OperationManagerFacade.sharedManager)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        presenter.setup()

        // then

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.activateExport()

        // then

        wait(for: [sharingExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(givenAccount, presenter.exportData?.account)
        XCTAssertEqual(derivationPath, presenter.exportData?.derivationPath)
    }
}
