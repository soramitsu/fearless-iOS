import XCTest
@testable import fearless
import SoraKeystore
import SoraFoundation
import RobinHood
import Cuckoo
import IrohaCrypto

class ExportMnemonicTests: XCTestCase {
    func testMnemonicCreationProvisionsBitcoinMainnetAccount() throws {
        let mnemonic = try IRMnemonicCreator().mnemonic(
            fromList: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: "Bitcoin wallet",
            substrateDerivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        let operation = MetaAccountOperationFactory(keystore: InMemoryKeychain())
            .newMetaAccountOperation(request: request, isBackuped: true)

        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let wallet = try operation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let account = try XCTUnwrap(wallet.fetch(
            for: UniversalWalletRegistry.bitcoinMainnetChainModel.accountRequest()
        ))

        XCTAssertTrue(account.isChainAccount)
        XCTAssertEqual(account.chainId, UniversalWalletRegistry.bitcoinMainnet.chainId)
        XCTAssertEqual(account.cryptoType, .ecdsa)
        XCTAssertTrue(account.toAddress()?.hasPrefix("bc1") == true)
    }

    func testSubstrateExport() throws {
        // given

        let keychain = InMemoryKeychain()

        let storageFacade = UserDataStorageTestFacade()
        let repository = AccountRepositoryFactory.createRepository(for: storageFacade)

        let derivationPath = "//some//work"
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().randomMnemonic(.entropy128),
            username: "fearless",
            substrateDerivationPath: derivationPath,
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        let createOperation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request, isBackuped: true)
        OperationQueue().addOperations([createOperation], waitUntilFinished: true)
        let givenAccount = try createOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        // when

        let view = MockExportGenericViewProtocol()

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.controller.get).thenReturn(UIViewController())

            when(stub.set(viewModel: any(MultipleExportGenericViewModelProtocol.self))).then { _ in
                setupExpectation.fulfill()
            }
        }

        let wireframe = MockExportMnemonicWireframeProtocol()

        let confirmationExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.present(viewModel: any(SheetAlertPresentableViewModel.self), from: any(ControllerBackedProtocol?.self))).then { viewModel in
                viewModel.0.actions.first?.handler?()
            }

            when(stub.openConfirmationForMnemonic(any(IRMnemonicProtocol.self), wallet: any(fearless.MetaAccountModel.self), from: any(ExportGenericViewProtocol?.self))).then { _ in
                confirmationExpectation.fulfill()
            }
        }
        
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: UInt16(fearless.SNAddressType.genericSubstrate.rawValue)
        )
        let accountResponse = fearless.ChainAccountResponse(
            chainId: chain.chainId,
            accountId: givenAccount.substrateAccountId,
            publicKey: givenAccount.substratePublicKey,
            name: givenAccount.name,
            cryptoType: CryptoType(rawValue: givenAccount.substrateCryptoType) ?? .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: givenAccount.metaId
        )

        let presenter = ExportMnemonicPresenter(flow: .multiple(wallet: givenAccount,
                                                                accounts: [ChainAccountInfo(chain: chain, account: accountResponse)]),
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

        wait(for: [confirmationExpectation], timeout: Constants.defaultExpectationDuration)
        
        guard let mnemonic = presenter.exportDatas?.first?.mnemonic,
              let substrateDerivationPath = presenter.exportDatas?.first?.derivationPath,
              let cryptoType = presenter.exportDatas?.first?.cryptoType else {
                  XCTFail()
                  return
              }
        let importRequest = MetaAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: "testUsername",
            substrateDerivationPath: substrateDerivationPath,
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: cryptoType,
            defaultChainId: nil
        )
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let importOperation = operationFactory.newMetaAccountOperation(request: importRequest, isBackuped: true)
        OperationQueue().addOperations([importOperation], waitUntilFinished: true)
        let importedAccount: MetaAccountModel = try importOperation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        XCTAssertEqual(givenAccount.substrateCryptoType, importedAccount.substrateCryptoType)
        XCTAssertEqual(givenAccount.substrateAccountId, importedAccount.substrateAccountId)
        XCTAssertEqual(givenAccount.substratePublicKey, importedAccount.substratePublicKey)
    }
    
    func testEthereumExport() throws {
        // given

        let keychain = InMemoryKeychain()

        let storageFacade = UserDataStorageTestFacade()
        let repository = AccountRepositoryFactory.createRepository(for: storageFacade)

        let derivationPath = DerivationPathConstants.testEthereum
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().randomMnemonic(.entropy128),
            username: "fearless",
            substrateDerivationPath: "",
            ethereumDerivationPath: derivationPath,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        let createOperation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request, isBackuped: true)
        OperationQueue().addOperations([createOperation], waitUntilFinished: true)
        let givenAccount = try createOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        // when

        let view = MockExportGenericViewProtocol()

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.controller.get).thenReturn(UIViewController())

            when(stub.set(viewModel: any(MultipleExportGenericViewModelProtocol.self))).then { _ in
                setupExpectation.fulfill()
            }
        }

        let wireframe = MockExportMnemonicWireframeProtocol()

        let confirmationExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.present(viewModel: any(SheetAlertPresentableViewModel.self), from: any(ControllerBackedProtocol?.self))).then { param in
                param.0.actions.first?.handler?()
            }

            when(stub.openConfirmationForMnemonic(any(IRMnemonicProtocol.self), wallet: any(fearless.MetaAccountModel.self), from: any(ExportGenericViewProtocol?.self))).then { _ in
                confirmationExpectation.fulfill()
            }
        }
        
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let ethereumPublicKey = try XCTUnwrap(givenAccount.ethereumPublicKey)
        let ethereumAddress = try XCTUnwrap(givenAccount.ethereumAddress)
        let accountResponse = fearless.ChainAccountResponse(
            chainId: chain.chainId,
            accountId: ethereumAddress,
            publicKey: ethereumPublicKey,
            name: givenAccount.name,
            cryptoType: .ecdsa,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: true,
            isChainAccount: false,
            walletId: givenAccount.metaId
        )

        let presenter = ExportMnemonicPresenter(flow: .multiple(wallet: givenAccount,
                                                                accounts: [ChainAccountInfo(chain: chain, account: accountResponse)]),
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

        wait(for: [confirmationExpectation], timeout: Constants.defaultExpectationDuration)
        
        guard let mnemonic = presenter.exportDatas?.first?.mnemonic else {
                  XCTFail()
                  return
              }
        let importRequest = MetaAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: "testUsername",
            substrateDerivationPath: "",
            ethereumDerivationPath: presenter.exportDatas?.first?.derivationPath ?? DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let importOperation = operationFactory.newMetaAccountOperation(request: importRequest, isBackuped: true)
        OperationQueue().addOperations([importOperation], waitUntilFinished: true)
        let importedAccount: MetaAccountModel = try importOperation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        XCTAssertEqual(givenAccount.substrateCryptoType, importedAccount.substrateCryptoType)
        XCTAssertEqual(givenAccount.substrateAccountId, importedAccount.substrateAccountId)
        XCTAssertEqual(givenAccount.substratePublicKey, importedAccount.substratePublicKey)
    }
}
