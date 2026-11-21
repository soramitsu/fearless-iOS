import XCTest
import UIKit
import SSFModels
import IrohaCrypto
import SoraFoundation
@testable import fearless

final class CovJImportView: UIViewController, AccountImportViewProtocol {
    var shown: AccountCreateChainType?
    var sourceType: AccountImportSource?
    var selectable: Bool?
    var source: InputViewModelProtocol?
    var name: InputViewModelProtocol?
    var nameVisible: Bool?
    var password: InputViewModelProtocol?
    var crypto: SelectableViewModel<TitleWithSubtitleViewModel>?
    var substrate: InputViewModelProtocol?
    var ethereum: InputViewModelProtocol?
    var warning: String?
    var unique: UniqueChainViewModel?
    var sourceCompletions = 0
    var cryptoCompletions = 0
    var substrateStatus: FieldStatus?
    var ethereumStatus: FieldStatus?
    var state: ErrorPresentableInputField.State?

    func show(chainType: AccountCreateChainType) { shown = chainType }
    func setSource(type: AccountImportSource, chainType: AccountCreateChainType, selectable: Bool) {
        sourceType = type
        self.selectable = selectable
    }
    func setSource(viewModel: InputViewModelProtocol) { source = viewModel }
    func setName(viewModel: InputViewModelProtocol, visible: Bool) { name = viewModel; nameVisible = visible }
    func setPassword(viewModel: InputViewModelProtocol) { password = viewModel }
    func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>) { crypto = model }
    func bind(substrateViewModel: InputViewModelProtocol) { substrate = substrateViewModel }
    func bind(ethereumViewModel: InputViewModelProtocol) { ethereum = ethereumViewModel }
    func setUploadWarning(message: String) { warning = message }
    func setUniqueChain(viewModel: UniqueChainViewModel) { unique = viewModel }
    func didChangeState(_ state: ErrorPresentableInputField.State) { self.state = state }
    func didCompleteSourceTypeSelection() { sourceCompletions += 1 }
    func didCompleteCryptoTypeSelection() { cryptoCompletions += 1 }
    func didValidateSubstrateDerivationPath(_ status: FieldStatus) { substrateStatus = status }
    func didValidateEthereumDerivationPath(_ status: FieldStatus) { ethereumStatus = status }
}

final class CovJImportInteractor: AccountImportInteractorInputProtocol {
    var setups = 0
    var metaRequests: [MetaAccountImportRequest] = []
    var chainRequests: [UniqueChainImportRequest] = []
    var keystores: [String] = []
    func setup() { setups += 1 }
    func importMetaAccount(request: MetaAccountImportRequest) { metaRequests.append(request) }
    func importUniqueChain(request: UniqueChainImportRequest) { chainRequests.append(request) }
    func deriveMetadataFromKeystore(_ keystore: String) { keystores.append(keystore) }
    func createMnemonicFromString(_ mnemonicString: String) -> IRMnemonicProtocol? { nil }
}

final class CovJImportRouter: AccountImportWireframeProtocol {
    var alerts: [SheetAlertPresentableViewModel] = []
    var errors: [Error] = []
    var sourceSelections = 0
    var cryptoSelections = 0
    var steps: [AccountCreationStep.SubstrateStepData] = []
    var completions = 0
    var handlesErrors = true

    func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) { alerts.append(viewModel) }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        errors.append(error)
        return handlesErrors
    }
    func showEthereumStep(from view: AccountImportViewProtocol?, with data: AccountCreationStep.SubstrateStepData) { steps.append(data) }
    func proceed(from view: AccountImportViewProtocol?, flow: AccountImportFlow) { completions += 1 }
    func presentSourceTypeSelection(from view: AccountImportViewProtocol?, availableSources: [AccountImportSource],
                                   selectedSource: AccountImportSource, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?) {
        sourceSelections += 1
    }
    func presentCryptoTypeSelection(from view: AccountImportViewProtocol?, availableTypes: [CryptoType],
                                   selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?) {
        cryptoSelections += 1
    }
}

final class CovJAccountImportPresenterTests: XCTestCase {
    private func metadata(source: AccountImportSource, crypto: CryptoType = .sr25519) -> MetaAccountImportMetadata {
        MetaAccountImportMetadata(availableSources: AccountImportSource.allCases, defaultSource: source,
                                  availableCryptoTypes: CryptoType.allCases, defaultCryptoType: crypto)
    }

    private func presenter(flow: AccountImportFlow = .wallet(step: .substrate)) -> (AccountImportPresenter, CovJImportView, CovJImportInteractor, CovJImportRouter) {
        let interactor = CovJImportInteractor()
        let router = CovJImportRouter()
        let view = CovJImportView()
        let presenter = AccountImportPresenter(wireframe: router, interactor: interactor, flow: flow)
        presenter.localizationManager = LocalizationManager.shared
        presenter.view = view
        return (presenter, view, interactor, router)
    }

    func testMetadataBuildsInputsForEverySourceAndCryptoType() {
        for source in AccountImportSource.allCases {
            for crypto in CryptoType.allCases {
                let (presenter, view, _, _) = presenter()
                presenter.didReceiveAccountImport(metadata: metadata(source: source, crypto: crypto))
                XCTAssertEqual(presenter.selectedSourceType, source)
                XCTAssertEqual(view.sourceType, source)
                XCTAssertEqual(view.selectable, true)
                XCTAssertEqual(view.nameVisible, true)
                XCTAssertEqual(presenter.selectedCryptoType, source == .legacyTonMnemonic ? .ed25519 : crypto)
                XCTAssertEqual(presenter.passwordViewModel != nil, source == .keystore)
                XCTAssertEqual(presenter.ethereumDerivationPathViewModel != nil, source == .mnemonic)
                XCTAssertEqual(presenter.substrateDerivationPathViewModel != nil, source == .mnemonic || source == .seed)
                XCTAssertNotNil(view.source?.placeholder)
                XCTAssertEqual(view.name?.inputHandler.completed, false)
            }
        }
    }

    func testPickerChangesSourceAndCryptoAndCancelCompletesOnlyMatchingPicker() {
        let (presenter, view, _, _) = presenter()
        presenter.didReceiveAccountImport(metadata: metadata(source: .mnemonic))
        let sources = AccountImportSource.allCases
        for (index, source) in sources.enumerated() {
            presenter.modalPickerDidSelectModelAtIndex(index, context: AccountImportContext.sourceType.rawValue as NSString)
            XCTAssertEqual(presenter.selectedSourceType, source)
        }
        XCTAssertEqual(view.sourceCompletions, sources.count)
        for (index, crypto) in CryptoType.allCases.enumerated() {
            presenter.modalPickerDidSelectModelAtIndex(index, context: AccountImportContext.cryptoType.rawValue as NSString)
            XCTAssertEqual(presenter.selectedCryptoType, crypto)
        }
        XCTAssertEqual(view.cryptoCompletions, CryptoType.allCases.count)
        presenter.modalPickerDidCancel(context: AccountImportContext.sourceType.rawValue as NSString)
        presenter.modalPickerDidCancel(context: AccountImportContext.cryptoType.rawValue as NSString)
        presenter.modalPickerDidCancel(context: "unrecognized" as NSString)
        presenter.modalPickerDidSelectModelAtIndex(0, context: nil)
        XCTAssertEqual(view.sourceCompletions, sources.count + 1)
        XCTAssertEqual(view.cryptoCompletions, CryptoType.allCases.count + 1)
    }

    func testKeystoreSuggestionValidatesFlowAndPopulatesPreferredName() {
        let (presenter, view, _, router) = presenter()
        presenter.didReceiveAccountImport(metadata: metadata(source: .mnemonic))
        let ethereum = MetaAccountImportPreferredInfo(username: "ETH", cryptoType: .ecdsa, isEthereum: true)
        XCTAssertFalse(presenter.validateJsonForStep(preferredInfo: ethereum))
        presenter.didSuggestKeystore(text: "{}", preferredInfo: ethereum)
        XCTAssertEqual(router.alerts.count, 1)
        XCTAssertEqual(presenter.selectedSourceType, .mnemonic)
        let substrate = MetaAccountImportPreferredInfo(username: "Imported", cryptoType: .sr25519, isEthereum: false)
        presenter.didSuggestKeystore(text: "{\"encoded\":\"fixture\"}", preferredInfo: substrate)
        XCTAssertEqual(presenter.selectedSourceType, .keystore)
        XCTAssertEqual(presenter.sourceViewModel?.inputHandler.value, "{\"encoded\":\"fixture\"}")
        XCTAssertEqual(presenter.usernameViewModel?.inputHandler.value, "Imported")
        XCTAssertNotNil(view.password)
        XCTAssertNil(presenter.substrateDerivationPathViewModel)
        XCTAssertNil(presenter.ethereumDerivationPathViewModel)
        presenter.didFailToDeriveMetadataFromKeystore()
        XCTAssertEqual(router.errors.last.map { String(describing: $0) }, "invalidKeystore")
    }

    func testEthereumStepRestoresPreviousMetadataAndHidesSourceSelection() {
        let data = AccountCreationStep.SubstrateStepData(sourceType: .seed, source: "previous", username: "Savings",
                                                       password: "test", cryptoType: .ed25519, derivationPath: "//1")
        let flow = AccountImportFlow.wallet(step: .ethereum(data: data))
        let (presenter, view, interactor, _) = presenter(flow: flow)
        presenter.setup()
        XCTAssertEqual(interactor.setups, 1)
        XCTAssertTrue(flow.isEthereumFlow)
        XCTAssertEqual(flow.provideSubstrateStepDataIfNeed()?.username, "Savings")
        XCTAssertEqual(presenter.selectedSourceType, .seed)
        XCTAssertEqual(presenter.selectedCryptoType, .ed25519)
        XCTAssertEqual(view.selectable, false)
        XCTAssertEqual(presenter.usernameViewModel?.inputHandler.value, "Savings")
        XCTAssertNotNil(presenter.ethereumDerivationPathViewModel)
        XCTAssertNil(presenter.substrateDerivationPathViewModel)
        XCTAssertTrue(presenter.validateJsonForStep(preferredInfo: MetaAccountImportPreferredInfo(username: nil, cryptoType: nil, isEthereum: true)))
    }

    func testChainFlowUsesWalletNameAndEthereumDerivation() {
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = CovJWalletConnectFixture.chain()
        let flow = AccountImportFlow.chain(model: UniqueChainModel(meta: wallet, chain: chain))
        let (presenter, view, interactor, _) = presenter(flow: flow)
        presenter.didReceiveAccountImport(metadata: metadata(source: .legacyTonMnemonic))
        presenter.setup()
        XCTAssertTrue(flow.isEthereumFlow)
        XCTAssertNil(flow.provideSubstrateStepDataIfNeed())
        XCTAssertEqual(interactor.setups, 1)
        XCTAssertEqual(presenter.selectedSourceType, .mnemonic)
        XCTAssertEqual(view.nameVisible, false)
        XCTAssertEqual(presenter.usernameViewModel?.inputHandler.value, String(wallet.name.prefix(32)))
        XCTAssertEqual(view.unique?.text, "Ethereum")
        XCTAssertNotNil(presenter.ethereumDerivationPathViewModel)
        XCTAssertNil(presenter.substrateDerivationPathViewModel)
        XCTAssertFalse(presenter.metadata?.availableSources.contains(.legacyTonMnemonic) ?? true)
    }

    func testLocalizationPreservesDraftAndInputValidationRemainsDeferred() throws {
        let (presenter, view, _, _) = presenter()
        view.loadViewIfNeeded()
        presenter.didReceiveAccountImport(metadata: metadata(source: .mnemonic))
        presenter.sourceViewModel?.inputHandler.changeValue(to: "abandon ability able")
        presenter.usernameViewModel?.inputHandler.changeValue(to: "Wallet")
        presenter.substrateDerivationPathViewModel?.inputHandler.changeValue(to: "//1")
        presenter.applyLocalization()
        XCTAssertEqual(presenter.sourceViewModel?.inputHandler.value, "abandon ability able")
        XCTAssertEqual(presenter.usernameViewModel?.inputHandler.value, "Wallet")
        XCTAssertEqual(presenter.substrateDerivationPathViewModel?.inputHandler.value, "//1")
        presenter.validateInput(value: "invalid!")
        guard case .normal? = view.state else { return XCTFail("On-the-fly validation is intentionally deferred") }
        XCTAssertFalse(AccountImportPresenter.onFlyValidationEnabled)
    }

    func testDerivationValidationUpdatesFieldStatusAndReportsInvalidPath() {
        for crypto in CryptoType.allCases {
            let (presenter, view, _, router) = presenter()
            presenter.didReceiveAccountImport(metadata: metadata(source: .mnemonic, crypto: crypto))
            presenter.validateSubstrateDerivationPath()
            XCTAssertEqual(view.substrateStatus, FieldStatus.none)
            presenter.substrateDerivationPathViewModel?.inputHandler.changeValue(to: "//1")
            presenter.validateSubstrateDerivationPath()
            XCTAssertEqual(view.substrateStatus, .valid)
            presenter.substrateDerivationPathViewModel?.inputHandler.changeValue(to: "invalid")
            presenter.validateSubstrateDerivationPath()
            XCTAssertEqual(view.substrateStatus, .invalid)
            XCTAssertEqual(router.errors.count, 1)
            presenter.validateEthereumDerivationPath()
            XCTAssertEqual(view.ethereumStatus, FieldStatus.none)
            presenter.ethereumDerivationPathViewModel?.inputHandler.changeValue(to: "//1")
            presenter.validateEthereumDerivationPath()
            XCTAssertEqual(view.ethereumStatus, .valid)
            presenter.ethereumDerivationPathViewModel?.inputHandler.changeValue(to: "//4294967296")
            presenter.validateEthereumDerivationPath()
            XCTAssertEqual(view.ethereumStatus, .invalid)
            XCTAssertEqual(router.errors.count, 2)
        }
    }

    func testInvalidSourcesDoNotReachPersistence() throws {
        let cases: [(AccountImportSource, String)] = [
            (.mnemonic, "not! a mnemonic"), (.mnemonic, Array(repeating: "word", count: 25).joined(separator: " ")),
            (.seed, "xyz"), (.seed, String(repeating: "a", count: 68)),
            (.keystore, ""), (.keystore, "invalid JSON"), (.keystore, String(repeating: "x", count: 4000))
        ]
        for (source, value) in cases {
            let (presenter, view, interactor, router) = presenter()
            let window = try CovJViewFixture.host(view)
            defer { window.isHidden = true }
            presenter.didReceiveAccountImport(metadata: metadata(source: source))
            presenter.sourceViewModel?.inputHandler.changeValue(to: value)
            presenter.usernameViewModel?.inputHandler.changeValue(to: "Wallet")
            presenter.proceed()
            XCTAssertEqual(router.errors.count, 1, value)
            XCTAssertTrue(interactor.metaRequests.isEmpty)
            XCTAssertTrue(interactor.chainRequests.isEmpty)
        }
    }

    func testSeedImportCanContinueToEthereumOrPersistOnlySubstrate() throws {
        for includeEthereum in [true, false] {
            let (presenter, view, interactor, router) = presenter()
            let window = try CovJViewFixture.host(view)
            defer { window.isHidden = true }
            presenter.didReceiveAccountImport(metadata: metadata(source: .seed))
            let seed = "0x" + String(repeating: "12", count: 32)
            presenter.sourceViewModel?.inputHandler.changeValue(to: seed)
            presenter.usernameViewModel?.inputHandler.changeValue(to: "Savings")
            presenter.selectSourceType()
            presenter.selectCryptoType()
            XCTAssertEqual(router.sourceSelections, 1)
            XCTAssertEqual(router.cryptoSelections, 1)
            presenter.proceed()
            let alert = try XCTUnwrap(router.alerts.last)
            XCTAssertEqual(alert.actions.count, 2)
            XCTAssertTrue(interactor.metaRequests.isEmpty)
            alert.actions[includeEthereum ? 0 : 1].handler?()
            if includeEthereum {
                XCTAssertEqual(router.steps.count, 1)
                XCTAssertEqual(router.steps[0].source, seed)
                XCTAssertEqual(router.steps[0].username, "Savings")
            } else {
                XCTAssertEqual(interactor.metaRequests.count, 1)
                presenter.proceed()
                XCTAssertEqual(interactor.metaRequests.count, 1)
            }
        }
    }
}
