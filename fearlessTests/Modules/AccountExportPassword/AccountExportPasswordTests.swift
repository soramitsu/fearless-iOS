import XCTest
@testable import fearless
import FearlessSecureStorage
import RobinHood
import FearlessFoundation
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
        let settings = SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue())
        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keychain,
            settings: settings
        )
        let wallet = try XCTUnwrap(settings.value)

        let view = MockAccountExportPasswordViewProtocol()
        let wireframe = MockAccountExportPasswordWireframeProtocol()

        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: UInt16(0))
        let walletAddress = try AddressFactory.address(for: wallet.substrateAccountId, chain: chain)

        let presenter = AccountExportPasswordPresenter(
            flow: .single(chain: chain, address: walletAddress, wallet: wallet),
            localizationManager: LocalizationManager.shared)

        presenter.view = view
        presenter.wireframe = wireframe

        let exportWrapper = KeystoreExportWrapper(keystore: keychain)
        let interactor = AccountExportPasswordInteractor(exportJsonWrapper: exportWrapper,
                                                         accountRepository: AnyDataProviderRepository(accountsRepository),
                                                         operationManager: OperationManagerFacade.sharedManager,
                                                         extrinsicOperationFactory: nil,
                                                         chainRepository: AnyDataProviderRepository(chainRepository))
        presenter.interactor = interactor
        interactor.presenter = presenter

        var inputViewModel: InputViewModelProtocol?
        var confirmationViewModel: InputViewModelProtocol?

        stub(view) { stub in
            when(stub.controller.get).thenReturn(UIViewController())

            when(stub.setPasswordInputViewModel(any(InputViewModelProtocol.self))).then { viewModel in
                inputViewModel = viewModel
            }

            when(stub.setPasswordConfirmationViewModel(any(InputViewModelProtocol.self))).then { viewModel in
                confirmationViewModel = viewModel
            }

            when(stub.set(error: any(AccountExportPasswordError.self))).thenDoNothing()
        }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.present(viewModel: any(SheetAlertPresentableViewModel.self), from: any(ControllerBackedProtocol?.self))).thenDoNothing()

            when(stub.showJSONExport(any([RestoreJson].self), flow: any(ExportFlow.self), from: any(AccountExportPasswordViewProtocol?.self))).then { _ in
                expectation.fulfill()
            }
            when(stub.present(message: any(String?.self), title: any(String.self), closeAction: any(String?.self), from: any(ControllerBackedProtocol?.self), actions: any([SheetAlertPresentableAction].self))).then { _ in
                XCTFail()
            }
        }

        let saveOperation = accountsRepository.saveOperation({ [wallet] }, { [] })
        OperationQueue().addOperations([saveOperation], waitUntilFinished: true)

        // when

        presenter.setup()

        inputViewModel?.inputHandler.changeValue(to: Constants.validSrKeystorePassword)
        confirmationViewModel?.inputHandler.changeValue(to: Constants.validSrKeystorePassword)

        presenter.proceed()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
