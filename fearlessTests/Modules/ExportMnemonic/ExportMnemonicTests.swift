import XCTest
@testable import fearless
import FearlessSecureStorage
import FearlessFoundation
import RobinHood
import Cuckoo
import IrohaCrypto

class ExportMnemonicTests: XCTestCase {
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

            when(stub.openConfirmationForMnemonics(any([IRMnemonicProtocol].self), wallet: any(fearless.MetaAccountModel.self), from: any(ExportGenericViewProtocol?.self))).then { _ in
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

            when(stub.openConfirmationForMnemonics(any([IRMnemonicProtocol].self), wallet: any(fearless.MetaAccountModel.self), from: any(ExportGenericViewProtocol?.self))).then { _ in
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

    func testActivateExport_whenDuplicateExportMnemonics_thenConfirmsUniqueMnemonics() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let firstMnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
        let secondMnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)

        let presenter = ExportMnemonicPresenter(
            flow: .multiple(wallet: wallet, accounts: []),
            localizationManager: LocalizationManager.shared
        )

        let wireframe = MockExportMnemonicWireframeProtocol()
        let confirmationExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.openConfirmationForMnemonics(any([IRMnemonicProtocol].self), wallet: any(fearless.MetaAccountModel.self), from: any(ExportGenericViewProtocol?.self))).then { params in
                XCTAssertEqual(params.0.map { $0.allWords() }, [firstMnemonic.allWords(), secondMnemonic.allWords()])
                confirmationExpectation.fulfill()
            }
        }

        presenter.wireframe = wireframe
        presenter.didReceive(exportDatas: [
            ExportMnemonicData(mnemonic: firstMnemonic, derivationPath: nil, cryptoType: .sr25519, chain: chain),
            ExportMnemonicData(mnemonic: firstMnemonic, derivationPath: "//custom", cryptoType: .sr25519, chain: chain),
            ExportMnemonicData(mnemonic: secondMnemonic, derivationPath: nil, cryptoType: .sr25519, chain: chain)
        ])

        presenter.activateExport()

        wait(for: [confirmationExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testConfirm_whenMultipleMnemonics_thenCompletesAfterLastMnemonic() throws {
        let firstMnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
        let secondMnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
        let wallet = AccountGenerator.generateMetaAccount()
        let eventCenter = ExportMnemonicEventCenterSpy()
        let output = AccountConfirmInteractorOutputSpy()
        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
        let interactor = ExportMnemonicConfirmInteractor(
            mnemonics: [firstMnemonic, secondMnemonic],
            settings: settings,
            wallet: wallet,
            eventCenter: eventCenter
        )
        interactor.presenter = output

        interactor.requestWords()
        interactor.confirm(words: firstMnemonic.allWords())

        XCTAssertEqual(output.completionCount, 0)
        XCTAssertEqual(eventCenter.changedWallets.count, 0)
        XCTAssertEqual(output.receivedWords.count, 2)

        interactor.confirm(words: secondMnemonic.allWords())

        XCTAssertEqual(output.completionCount, 1)
        XCTAssertEqual(eventCenter.changedWallets.map(\.hasBackup), [true])
    }
}

private final class AccountConfirmInteractorOutputSpy: AccountConfirmInteractorOutputProtocol {
    private(set) var receivedWords: [([String], Bool)] = []
    private(set) var completionCount = 0
    private(set) var errors: [Error] = []

    func didReceive(words: [String], afterConfirmationFail: Bool) {
        receivedWords.append((words, afterConfirmationFail))
    }

    func didCompleteConfirmation() {
        completionCount += 1
    }

    func didReceive(error: Error) {
        errors.append(error)
    }
}

private final class ExportMnemonicEventCenterSpy: EventCenterProtocol {
    private(set) var changedWallets: [fearless.MetaAccountModel] = []

    func notify(with event: EventProtocol) {
        guard let changedEvent = event as? MetaAccountModelChangedEvent else {
            return
        }

        changedWallets.append(changedEvent.account)
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}

    func remove(observer _: EventVisitorProtocol) {}
}
