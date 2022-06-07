import XCTest
@testable import fearless
import SoraKeystore
import SoraFoundation
import RobinHood
import Cuckoo

class ExportMnemonicTests: XCTestCase {
    func testSubstrateExport() throws {
        // given

        let keychain = InMemoryKeychain()
        let settings = SelectedWalletSettings.shared

        let storageFacade = UserDataStorageTestFacade()
        let repository = AccountRepositoryFactory.createRepository(for: storageFacade)

        let derivationPath = "//some//work"

        try AccountCreationHelper.createMetaAccountFromMnemonic(cryptoType: .sr25519,
                                                                substrateDerivationPath: derivationPath,
                                                                keychain: keychain,
                                                                settings: settings)

        let givenAccount = settings.value!

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
        
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1,
                                                      addressPrefix: UInt16(SNAddressType.genericSubstrate.rawValue))

        let presenter = ExportMnemonicPresenter(flow: .single(chain: chain,
                                                              address: AddressTestConstants.polkadotAddress, wallet: givenAccount),
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
        
        guard let mnemonic = presenter.exportDatas?.first?.mnemonic,
              let substrateDerivationPath = presenter.exportDatas?.first?.derivationPath,
              let cryptoType = presenter.exportDatas?.first?.cryptoType else {
                  XCTFail()
                  return
              }
        let importRequest = MetaAccountImportMnemonicRequest(mnemonic: mnemonic,
                                                             username: "testUsername",
                                                             substrateDerivationPath: substrateDerivationPath,
                                                             ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                                                             cryptoType: cryptoType)
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let importedAccount = try operationFactory.newMetaAccountOperation(request: importRequest).extractResultData()

        XCTAssertEqual(givenAccount.substrateCryptoType, importedAccount?.substrateCryptoType)
        XCTAssertEqual(givenAccount.substrateAccountId, importedAccount?.substrateAccountId)
        XCTAssertEqual(givenAccount.substratePublicKey, importedAccount?.substratePublicKey)
    }
    
    func testEthereumExport() throws {
        // given

        let keychain = InMemoryKeychain()
        let settings = SelectedWalletSettings.shared

        let storageFacade = UserDataStorageTestFacade()
        let repository = AccountRepositoryFactory.createRepository(for: storageFacade)

        let derivationPath = DerivationPathConstants.testEthereum
        
        try AccountCreationHelper.createMetaAccountFromMnemonic(cryptoType: .sr25519,
                                                                ethereumDerivationPath: derivationPath,
                                                                keychain: keychain,
                                                                settings: settings)
        
        let givenAccount = settings.value!

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
        
//  Replace to ethereum chain
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1,
                                                      addressPrefix: 0)

        let presenter = ExportMnemonicPresenter(flow: .single(chain: chain, address: AddressTestConstants.ethereumAddres,
                                                              wallet: givenAccount),
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
        
        guard let mnemonic = presenter.exportDatas?.first?.mnemonic,
              let substrateDerivationPath = presenter.exportDatas?.first?.derivationPath,
              let cryptoType = presenter.exportDatas?.first?.cryptoType else {
                  XCTFail()
                  return
              }
        let importRequest = MetaAccountImportMnemonicRequest(mnemonic: mnemonic,
                                                             username: "testUsername",
                                                             substrateDerivationPath: substrateDerivationPath,
                                                             ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                                                             cryptoType: cryptoType)
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let importedAccount = try operationFactory.newMetaAccountOperation(request: importRequest).extractResultData()

        XCTAssertEqual(givenAccount.substrateCryptoType, importedAccount?.substrateCryptoType)
        XCTAssertEqual(givenAccount.substrateAccountId, importedAccount?.substrateAccountId)
        XCTAssertEqual(givenAccount.substratePublicKey, importedAccount?.substratePublicKey)
    }
}
