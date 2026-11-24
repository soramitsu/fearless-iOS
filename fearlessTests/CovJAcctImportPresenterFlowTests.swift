import XCTest
import UIKit
import SSFModels
import IrohaCrypto
import SoraFoundation
@testable import fearless

// MARK: - Stubs shared by the CovJAcct account-import presenter tests

final class CovJAcctImportViewStub: UIViewController, AccountImportViewProtocol, AccountImportPersistenceView {
    var chainTypes: [AccountCreateChainType] = []
    var sources: [(AccountImportSource, AccountCreateChainType, Bool)] = []
    var sourceModel: InputViewModelProtocol?
    var nameVisible: Bool?
    var passwordModel: InputViewModelProtocol?
    var crypto: SelectableViewModel<TitleWithSubtitleViewModel>?
    var substrateModel: InputViewModelProtocol?
    var ethereumModel: InputViewModelProtocol?
    var uploadWarning: String?
    var uniqueChain: UniqueChainViewModel?
    var substrateStatuses: [FieldStatus] = []
    var ethereumStatuses: [FieldStatus] = []
    var persistence: [(pending: Bool, committed: Bool)] = []

    func show(chainType: AccountCreateChainType) { chainTypes.append(chainType) }
    func setSource(type: AccountImportSource, chainType: AccountCreateChainType, selectable: Bool) {
        sources.append((type, chainType, selectable))
    }

    func setSource(viewModel: InputViewModelProtocol) { sourceModel = viewModel }
    func setName(viewModel _: InputViewModelProtocol, visible: Bool) { nameVisible = visible }
    func setPassword(viewModel: InputViewModelProtocol) { passwordModel = viewModel }
    func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>) { crypto = model }
    func bind(substrateViewModel: InputViewModelProtocol) { substrateModel = substrateViewModel }
    func bind(ethereumViewModel: InputViewModelProtocol) { ethereumModel = ethereumViewModel }
    func setUploadWarning(message: String) { uploadWarning = message }
    func setUniqueChain(viewModel: UniqueChainViewModel) { uniqueChain = viewModel }
    func didChangeState(_: ErrorPresentableInputField.State) {}
    func didCompleteSourceTypeSelection() {}
    func didCompleteCryptoTypeSelection() {}
    func didValidateSubstrateDerivationPath(_ status: FieldStatus) { substrateStatuses.append(status) }
    func didValidateEthereumDerivationPath(_ status: FieldStatus) { ethereumStatuses.append(status) }
    func bindImportPersistence(pending: Bool, committed: Bool) { persistence.append((pending, committed)) }
}

final class CovJAcctImportInteractorStub: AccountImportInteractorInputProtocol {
    var setups = 0
    var metaRequests: [MetaAccountImportRequest] = []
    var chainRequests: [UniqueChainImportRequest] = []
    var keystores: [String] = []

    func setup() { setups += 1 }
    func importMetaAccount(request: MetaAccountImportRequest) { metaRequests.append(request) }
    func importUniqueChain(request: UniqueChainImportRequest) { chainRequests.append(request) }
    func deriveMetadataFromKeystore(_ keystore: String) { keystores.append(keystore) }
    func createMnemonicFromString(_ mnemonicString: String) -> IRMnemonicProtocol? {
        try? IRMnemonicCreator().mnemonic(fromList: mnemonicString)
    }
}

final class CovJAcctImportRouterStub: AccountImportWireframeProtocol {
    var alerts: [SheetAlertPresentableViewModel] = []
    var errors: [Error] = []
    var handlesErrors = true
    var steps: [AccountCreationStep.SubstrateStepData] = []
    var proceeds: [AccountImportFlow] = []
    var filePickers: [[DocumentType]] = []
    var dismissals = 0

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { alerts.append(viewModel) }
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return handlesErrors
    }

    func showEthereumStep(from _: AccountImportViewProtocol?, with data: AccountCreationStep.SubstrateStepData) {
        steps.append(data)
    }

    func proceed(from _: AccountImportViewProtocol?, flow: AccountImportFlow) { proceeds.append(flow) }
    func presentSourceTypeSelection(
        from _: AccountImportViewProtocol?, availableSources _: [AccountImportSource], selectedSource _: AccountImportSource,
        delegate _: ModalPickerViewControllerDelegate?, context _: AnyObject?
    ) {}

    func presentCryptoTypeSelection(
        from _: AccountImportViewProtocol?, availableTypes _: [CryptoType], selectedType _: CryptoType,
        delegate _: ModalPickerViewControllerDelegate?, context _: AnyObject?
    ) {}

    func presentSelectFilePicker(from _: ControllerBackedProtocol?, documentTypes: [DocumentType], delegate _: UIDocumentPickerDelegate) {
        filePickers.append(documentTypes)
    }

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
}

/// A hosted presenter with its stubs; `close()` hides the window.
struct CovJAcctImportHarness {
    let presenter: AccountImportPresenter
    let view: CovJAcctImportViewStub
    let interactor: CovJAcctImportInteractorStub
    let router: CovJAcctImportRouterStub
    let window: UIWindow?

    static let phrase = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
    static let seed = "0x" + String(repeating: "ab", count: 32)
    static let locale = Locale(identifier: "en_US")

    static func make(flow: AccountImportFlow = .wallet(step: .substrate), hosted: Bool = true) throws -> CovJAcctImportHarness {
        let interactor = CovJAcctImportInteractorStub()
        let router = CovJAcctImportRouterStub()
        let view = CovJAcctImportViewStub()
        let presenter = AccountImportPresenter(wireframe: router, interactor: interactor, flow: flow)
        presenter.localizationManager = LocalizationManager.shared
        presenter.view = view
        let window = hosted ? try CovJViewFixture.host(view) : nil
        return CovJAcctImportHarness(presenter: presenter, view: view, interactor: interactor, router: router, window: window)
    }

    static func metadata(_ source: AccountImportSource, crypto: CryptoType = .sr25519) -> MetaAccountImportMetadata {
        MetaAccountImportMetadata(
            availableSources: AccountImportSource.allCases, defaultSource: source,
            availableCryptoTypes: CryptoType.allCases, defaultCryptoType: crypto
        )
    }

    func load(_ source: AccountImportSource, crypto: CryptoType = .sr25519, value: String, username: String = "Main") {
        presenter.didReceiveAccountImport(metadata: Self.metadata(source, crypto: crypto))
        presenter.sourceViewModel?.inputHandler.changeValue(to: value)
        presenter.usernameViewModel?.inputHandler.changeValue(to: username)
    }

    func close() { window?.isHidden = true }
}

// MARK: - Wallet flow

final class CovJAcctImportPresenterFlowTests: XCTestCase {
    private typealias Harness = CovJAcctImportHarness

    func testMnemonicImportPersistsOnceAndNavigatesAfterAcknowledgement() throws {
        let harness = try Harness.make()
        defer { harness.close() }
        harness.load(.mnemonic, value: Harness.phrase)

        harness.presenter.proceed()
        harness.presenter.proceed()

        XCTAssertEqual(harness.interactor.metaRequests.count, 1)
        let request = try XCTUnwrap(harness.interactor.metaRequests.first)
        XCTAssertEqual(request.username, "Main")
        XCTAssertEqual(request.cryptoType, .sr25519)
        XCTAssertNil(request.defaultChainId)
        guard case let .mnemonic(data) = request.source else { return XCTFail("Expected a mnemonic request") }
        XCTAssertEqual(data.mnemonic.toString(), Harness.phrase)
        XCTAssertEqual(data.substrateDerivationPath, "")
        XCTAssertEqual(data.ethereumDerivationPath, DerivationPathConstants.defaultEthereum)
        XCTAssertEqual(data.substratePasswordRule, .nfkd)
        XCTAssertEqual(harness.view.persistence.last?.pending, true)
        XCTAssertEqual(harness.view.persistence.last?.committed, false)

        harness.presenter.didCompleteAccountImport()

        XCTAssertEqual(harness.router.proceeds.count, 1)
        XCTAssertEqual(harness.view.persistence.last?.pending, false)
        XCTAssertEqual(harness.view.persistence.last?.committed, true)

        harness.presenter.didReceiveAccountImport(error: CovJError())
        harness.presenter.didCompleteAccountImport()
        harness.presenter.proceed()
        XCTAssertTrue(harness.router.errors.isEmpty)
        XCTAssertEqual(harness.router.proceeds.count, 1)
        XCTAssertEqual(harness.interactor.metaRequests.count, 1)
    }

    func testSupersededSelectionWaitsForExplicitContinue() throws {
        let harness = try Harness.make()
        defer { harness.close() }
        harness.load(.mnemonic, value: Harness.phrase)
        harness.presenter.proceed()

        harness.presenter.completeAccountImport(selectionIsCurrent: false)
        XCTAssertTrue(harness.router.proceeds.isEmpty)
        XCTAssertEqual(harness.view.persistence.last?.committed, true)

        harness.presenter.proceed()
        XCTAssertEqual(harness.router.proceeds.count, 1)
        XCTAssertEqual(harness.interactor.metaRequests.count, 1)
    }

    func testSuspendedFailureIsSilentAndRetryIssuesNewRequest() throws {
        let harness = try Harness.make()
        defer { harness.close() }
        harness.load(.mnemonic, value: Harness.phrase)
        harness.presenter.proceed()

        harness.presenter.suspendPendingImportPresentation()
        harness.presenter.didReceiveAccountImport(error: CovJError("late"))
        XCTAssertTrue(harness.router.errors.isEmpty)
        XCTAssertEqual(harness.view.persistence.last?.pending, false)

        harness.presenter.proceed()
        XCTAssertEqual(harness.interactor.metaRequests.count, 1, "Suspended presentation must not start a new import")

        harness.presenter.resumeImportPresentation()
        harness.presenter.proceed()
        XCTAssertEqual(harness.interactor.metaRequests.count, 2)
    }

    func testUnhandledErrorFallsBackToUndefinedError() throws {
        let harness = try Harness.make()
        defer { harness.close() }
        harness.router.handlesErrors = false
        harness.load(.mnemonic, value: Harness.phrase)
        harness.presenter.proceed()

        harness.presenter.didReceiveAccountImport(error: CovJError("save failed"))

        XCTAssertEqual(harness.router.errors.count, 2)
        XCTAssertEqual(harness.router.errors.first as? CovJError, CovJError("save failed"))
        guard case .undefined? = harness.router.errors.last as? CommonError else {
            return XCTFail("Expected the undefined fallback error")
        }
    }

    func testInvalidMnemonicChecksumReportsFormatErrorAndAllowsRetry() throws {
        let harness = try Harness.make()
        defer { harness.close() }
        harness.load(.mnemonic, value: Array(repeating: "abandon", count: 12).joined(separator: " "))

        harness.presenter.proceed()

        XCTAssertTrue(harness.interactor.metaRequests.isEmpty)
        XCTAssertEqual(harness.router.errors.count, 1)
        XCTAssertEqual(harness.router.errors.first as? AccountCreateError, .invalidMnemonicFormat)

        harness.presenter.sourceViewModel?.inputHandler.changeValue(to: Harness.phrase)
        harness.presenter.proceed()
        XCTAssertEqual(harness.interactor.metaRequests.count, 1)
    }

    func testNonAsciiPasswordAsksWhichAccountAndImportsChosenRule() throws {
        for (index, rule) in [SubstratePasswordRule.nfkd, .nfc].enumerated() {
            let harness = try Harness.make()
            defer { harness.close() }
            harness.load(.mnemonic, value: Harness.phrase)
            harness.presenter.substrateDerivationPathViewModel?.inputHandler.changeValue(to: "//1///\u{E9}")

            harness.presenter.proceed()

            XCTAssertTrue(harness.interactor.metaRequests.isEmpty)
            let alert = try XCTUnwrap(harness.router.alerts.last)
            let languages = Harness.locale.rLanguages
            XCTAssertEqual(alert.title, R.string.localizable.substratePasswordChoiceTitle(preferredLanguages: languages))
            XCTAssertTrue(alert.scrollableContent)
            XCTAssertEqual(alert.actions.map(\.title), [
                R.string.localizable.substratePasswordChoiceNfkd(preferredLanguages: languages),
                R.string.localizable.substratePasswordChoiceNfc(preferredLanguages: languages)
            ])
            XCTAssertTrue(alert.actions.allSatisfy(\.handlerAfterDismissal))
            XCTAssertTrue(alert.message?.hasPrefix(
                R.string.localizable.substratePasswordChoiceMessage(preferredLanguages: languages)
            ) ?? false)

            alert.actions[index].handler?()

            let request = try XCTUnwrap(harness.interactor.metaRequests.first)
            guard case let .mnemonic(data) = request.source else { return XCTFail("Expected a mnemonic request") }
            XCTAssertEqual(data.substratePasswordRule, rule)
            XCTAssertEqual(data.substrateDerivationPath, "//1///\u{E9}")
            alert.actions[index].handler?()
            XCTAssertEqual(harness.interactor.metaRequests.count, 1)
        }
    }

    func testKeystoreImportAsksForEthereumAndPersistsSubstrateOnly() throws {
        for addEthereum in [true, false] {
            let harness = try Harness.make()
            defer { harness.close() }
            let json = "{\"encoded\":\"substrate\"}"
            harness.load(.keystore, value: json, username: "Json")
            harness.presenter.passwordViewModel?.inputHandler.changeValue(to: "secret")

            harness.presenter.proceed()

            let alert = try XCTUnwrap(harness.router.alerts.last)
            let languages = Harness.locale.rLanguages
            XCTAssertEqual(alert.title, R.string.localizable.alertAddEthereumTitle(preferredLanguages: languages))
            XCTAssertEqual(alert.actions.map(\.title), [
                R.string.localizable.commonYes(preferredLanguages: languages),
                R.string.localizable.commonNo(preferredLanguages: languages)
            ])
            alert.actions[addEthereum ? 0 : 1].handler?()

            if addEthereum {
                let step = try XCTUnwrap(harness.router.steps.first)
                XCTAssertEqual(step.sourceType, .keystore)
                XCTAssertEqual(step.source, json)
                XCTAssertEqual(step.password, "secret")
                XCTAssertEqual(step.username, "Json")
                XCTAssertTrue(harness.interactor.metaRequests.isEmpty)
            } else {
                let request = try XCTUnwrap(harness.interactor.metaRequests.first)
                guard case let .keystore(data) = request.source else { return XCTFail("Expected a keystore request") }
                XCTAssertEqual(data.substrateKeystore, json)
                XCTAssertEqual(data.substratePassword, "secret")
                XCTAssertNil(data.ethereumKeystore)
                XCTAssertNil(data.ethereumPassword)
                XCTAssertEqual(request.username, "Json")
            }
        }
    }

    func testSeedImportWithoutEthereumPersistsSubstrateSeed() throws {
        let harness = try Harness.make()
        defer { harness.close() }
        harness.load(.seed, crypto: .ed25519, value: Harness.seed)
        harness.presenter.substrateDerivationPathViewModel?.inputHandler.changeValue(to: "//2")

        harness.presenter.proceed()
        try XCTUnwrap(harness.router.alerts.last).actions[1].handler?()

        let request = try XCTUnwrap(harness.interactor.metaRequests.first)
        XCTAssertEqual(request.cryptoType, .ed25519)
        guard case let .seed(data) = request.source else { return XCTFail("Expected a seed request") }
        XCTAssertEqual(data.substrateSeed, Harness.seed)
        XCTAssertEqual(data.substrateDerivationPath, "//2")
        XCTAssertNil(data.ethereumSeed)
        XCTAssertNil(data.ethereumDerivationPath)
    }

    func testEthereumStepSeedCombinesBothSeeds() throws {
        let previous = AccountCreationStep.SubstrateStepData(
            sourceType: .seed, source: Harness.seed, username: "Savings", password: "", cryptoType: .ed25519, derivationPath: "//1"
        )
        let harness = try Harness.make(flow: .wallet(step: .ethereum(data: previous)))
        defer { harness.close() }
        harness.presenter.setup()
        let ethereumSeed = "0x" + String(repeating: "cd", count: 32)
        harness.presenter.sourceViewModel?.inputHandler.changeValue(to: ethereumSeed)

        harness.presenter.proceed()

        XCTAssertEqual(harness.view.sources.last?.1, .ethereum)
        XCTAssertEqual(harness.view.sources.last?.2, false)
        XCTAssertEqual(harness.view.chainTypes.last, .ethereum)
        let request = try XCTUnwrap(harness.interactor.metaRequests.first)
        XCTAssertEqual(request.username, "Savings")
        XCTAssertEqual(request.cryptoType, .ed25519)
        guard case let .seed(data) = request.source else { return XCTFail("Expected a seed request") }
        XCTAssertEqual(data.substrateSeed, Harness.seed)
        XCTAssertEqual(data.ethereumSeed, ethereumSeed)
        XCTAssertEqual(data.substrateDerivationPath, "//1")
        XCTAssertEqual(data.ethereumDerivationPath, DerivationPathConstants.defaultEthereum)
    }

    func testEthereumStepKeystoreCombinesBothKeystores() throws {
        let previous = AccountCreationStep.SubstrateStepData(
            sourceType: .keystore, source: "{\"s\":1}", username: "Json", password: "p1", cryptoType: .sr25519, derivationPath: ""
        )
        let harness = try Harness.make(flow: .wallet(step: .ethereum(data: previous)))
        defer { harness.close() }
        harness.presenter.setup()
        harness.presenter.sourceViewModel?.inputHandler.changeValue(to: "{\"e\":2}")
        harness.presenter.passwordViewModel?.inputHandler.changeValue(to: "p2")

        harness.presenter.proceed()

        XCTAssertNotNil(harness.view.passwordModel)
        XCTAssertNil(harness.presenter.substrateDerivationPathViewModel)
        XCTAssertNil(harness.presenter.ethereumDerivationPathViewModel)
        let request = try XCTUnwrap(harness.interactor.metaRequests.first)
        XCTAssertEqual(request.username, "Json")
        guard case let .keystore(data) = request.source else { return XCTFail("Expected a keystore request") }
        XCTAssertEqual(data.substrateKeystore, "{\"s\":1}")
        XCTAssertEqual(data.ethereumKeystore, "{\"e\":2}")
        XCTAssertEqual(data.substratePassword, "p1")
        XCTAssertEqual(data.ethereumPassword, "p2")
    }

    func testZeroEthereumPathAsksBeforeImportingWithEitherAnswer() throws {
        for index in [0, 1] {
            let harness = try Harness.make()
            defer { harness.close() }
            harness.load(.mnemonic, value: Harness.phrase)
            harness.presenter.ethereumDerivationPathViewModel?.inputHandler.changeValue(to: DerivationPathConstants.zerosEthereum)

            harness.presenter.proceed()

            XCTAssertTrue(harness.interactor.metaRequests.isEmpty)
            let alert = try XCTUnwrap(harness.router.alerts.last)
            let languages = Harness.locale.rLanguages
            XCTAssertEqual(alert.title, "")
            XCTAssertEqual(alert.message, R.string.localizable.importEmptyDerivationMessage(preferredLanguages: languages))
            XCTAssertEqual(alert.actions.map(\.title), [
                R.string.localizable.importEmptyDerivationConfirm(preferredLanguages: languages),
                R.string.localizable.importEmptyDerivationCancel(preferredLanguages: languages)
            ])

            alert.actions[index].handler?()

            XCTAssertEqual(harness.view.ethereumStatuses.last, .valid)
            let request = try XCTUnwrap(harness.interactor.metaRequests.first)
            guard case let .mnemonic(data) = request.source else { return XCTFail("Expected a mnemonic request") }
            XCTAssertEqual(data.ethereumDerivationPath, DerivationPathConstants.zerosEthereum)
        }
    }
}
