import XCTest
import UIKit
import SSFModels
import IrohaCrypto
import SoraFoundation
@testable import fearless

final class CovJAcctCreateViewStub: UIViewController, AccountCreateViewProtocol {
    var mnemonics: [[String]] = []
    var chainTypes: [AccountCreateChainType] = []
    var substrateCrypto: [SelectableViewModel<TitleWithSubtitleViewModel>] = []
    var ethereumCrypto: [TitleWithSubtitleViewModel] = []
    var substrateModel: InputViewModelProtocol?
    var ethereumModel: InputViewModelProtocol?
    var cryptoCompletions = 0
    var substrateStatuses: [FieldStatus] = []
    var ethereumStatuses: [FieldStatus] = []

    func set(mnemonic: [String]) { mnemonics.append(mnemonic) }
    func set(chainType: AccountCreateChainType) { chainTypes.append(chainType) }
    func setSelectedSubstrateCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>) { substrateCrypto.append(model) }
    func setEthereumCrypto(model: TitleWithSubtitleViewModel) { ethereumCrypto.append(model) }
    func bind(substrateViewModel: InputViewModelProtocol) { substrateModel = substrateViewModel }
    func bind(ethereumViewModel: InputViewModelProtocol) { ethereumModel = ethereumViewModel }
    func didCompleteCryptoTypeSelection() { cryptoCompletions += 1 }
    func didValidateSubstrateDerivationPath(_ status: FieldStatus) { substrateStatuses.append(status) }
    func didValidateEthereumDerivationPath(_ status: FieldStatus) { ethereumStatuses.append(status) }
}

final class CovJAcctCreateInteractorStub: AccountCreateInteractorInputProtocol {
    var setups = 0
    func setup() { setups += 1 }
    func createMnemonicFromString(_ mnemonicString: String) -> IRMnemonicProtocol? {
        try? IRMnemonicCreator().mnemonic(fromList: mnemonicString)
    }
}

final class CovJAcctCreateWireframeStub: AccountCreateWireframeProtocol {
    var confirms: [AccountConfirmFlow] = []
    var cryptoSelections: [([CryptoType], CryptoType)] = []
    var backups: [MetaAccountImportMnemonicRequest] = []
    var errors: [Error] = []
    var messages: [(String?, String)] = []
    var handlesErrors = true

    func confirm(from _: AccountCreateViewProtocol?, flow: AccountConfirmFlow) { confirms.append(flow) }
    func presentCryptoTypeSelection(
        from _: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType,
        delegate _: ModalPickerViewControllerDelegate?, context _: AnyObject?
    ) {
        cryptoSelections.append((availableTypes, selectedType))
    }

    func showBackupCreatePassword(request: MetaAccountImportMnemonicRequest, from _: ControllerBackedProtocol?) {
        backups.append(request)
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return handlesErrors
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}
    func present(
        message: String?, title: String, closeAction _: String?, from _: ControllerBackedProtocol?, actions _: [SheetAlertPresentableAction]
    ) {
        messages.append((message, title))
    }
}

final class CovJAcctCreatePresenterTests: XCTestCase {
    private let phrase = CovJAcctImportHarness.phrase
    private var languages: [String]? { LocalizationManager.shared.selectedLocale.rLanguages }

    private func make(
        flow: AccountCreateFlow = .wallet
    ) -> (AccountCreatePresenter, CovJAcctCreateViewStub, CovJAcctCreateInteractorStub, CovJAcctCreateWireframeStub) {
        let view = CovJAcctCreateViewStub()
        let interactor = CovJAcctCreateInteractorStub()
        let wireframe = CovJAcctCreateWireframeStub()
        let presenter = AccountCreatePresenter(
            usernameSetup: UsernameSetupModel(username: "Fresh"), wireframe: wireframe, interactor: interactor, flow: flow
        )
        presenter.view = view
        presenter.localizationManager = LocalizationManager.shared
        return (presenter, view, interactor, wireframe)
    }

    private func wallet(cryptoType: UInt8) -> MetaAccountModel {
        let base = AccountGenerator.generateMetaAccount()
        return MetaAccountModel(
            metaId: base.metaId, name: "Base", substrateAccountId: base.substrateAccountId, substrateCryptoType: cryptoType,
            substratePublicKey: base.substratePublicKey, ethereumAddress: base.ethereumAddress, ethereumPublicKey: base.ethereumPublicKey,
            chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: true, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: nil, assetsVisibility: [], hasBackup: true,
            favouriteChainIds: []
        )
    }

    func testWalletSetupBindsBothChainsAndDerivationModels() {
        let (presenter, view, interactor, _) = make()

        presenter.setup()

        let locale = LocalizationManager.shared.selectedLocale
        XCTAssertEqual(interactor.setups, 1)
        XCTAssertEqual(view.chainTypes, [.both])
        XCTAssertEqual(view.substrateCrypto.last?.underlyingViewModel.title, CryptoType.sr25519.titleForLocale(locale))
        XCTAssertEqual(view.substrateCrypto.last?.selectable, true)
        XCTAssertEqual(view.ethereumCrypto.last?.title, CryptoType.ecdsa.titleForLocale(locale))
        XCTAssertEqual(view.substrateModel?.placeholder, DerivationPathConstants.hardSoftPasswordPlaceholder)
        XCTAssertEqual(view.ethereumModel?.placeholder, DerivationPathConstants.defaultEthereum)
        XCTAssertEqual(view.substrateStatuses, [.none])
        XCTAssertEqual(view.ethereumStatuses, [.none])
    }

    func testChainSetupUsesWalletCryptoTypeAndLocksSelection() {
        let substrateChain = CovJFixture.chain(name: "Kusama", addressPrefix: 2)
        let (presenter, view, _, _) = make(flow: .chain(model: UniqueChainModel(meta: wallet(cryptoType: 1), chain: substrateChain)))
        presenter.setup()
        XCTAssertEqual(view.chainTypes, [.substrate])
        XCTAssertEqual(view.substrateCrypto.last?.selectable, false)
        XCTAssertEqual(view.substrateModel?.placeholder, DerivationPathConstants.hardPasswordPlaceholder)

        let ethereumChain = CovJFixture.chain(name: "Moonbeam", options: [.ethereumBased])
        let (ethPresenter, ethView, _, _) = make(flow: .chain(model: UniqueChainModel(meta: wallet(cryptoType: 0), chain: ethereumChain)))
        ethPresenter.setup()
        XCTAssertEqual(ethView.chainTypes, [.ethereum])
    }

    func testInfoAndCryptoSelectionAndPickerCallbacks() throws {
        let (presenter, view, _, wireframe) = make()
        let window = try CovJViewFixture.host(view)
        defer {
            view.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        presenter.setup()

        presenter.activateInfo()
        let title = R.string.localizable.commonInfo(preferredLanguages: languages)
        XCTAssertTrue(wireframe.messages.first?.1 == title || view.presentedViewController is SheetAletViewController)

        presenter.selectSubstrateCryptoType()
        XCTAssertEqual(wireframe.cryptoSelections.first?.0, CryptoType.allCases)
        XCTAssertEqual(wireframe.cryptoSelections.first?.1, .sr25519)

        presenter.modalPickerDidSelectModelAtIndex(1, context: nil)
        let locale = LocalizationManager.shared.selectedLocale
        XCTAssertEqual(view.substrateCrypto.last?.underlyingViewModel.title, CryptoType.allCases[1].titleForLocale(locale))
        XCTAssertEqual(view.substrateModel?.placeholder, DerivationPathConstants.hardPasswordPlaceholder)
        XCTAssertEqual(view.cryptoCompletions, 1)
        presenter.selectSubstrateCryptoType()
        XCTAssertEqual(wireframe.cryptoSelections.last?.1, CryptoType.allCases[1])
        presenter.modalPickerDidCancel(context: nil)
        XCTAssertEqual(view.cryptoCompletions, 2)

        let before = view.substrateCrypto.count
        presenter.applyLocalization()
        XCTAssertEqual(view.substrateCrypto.count, before + 1)
        XCTAssertEqual(view.ethereumCrypto.count, 2)
    }

    func testDerivationValidationReportsStatusAndErrors() {
        let (presenter, view, _, wireframe) = make()
        presenter.validateSubstrate()
        presenter.validateEthereum()
        XCTAssertTrue(view.substrateStatuses.isEmpty, "Nothing to validate before setup")

        presenter.setup()
        view.substrateModel?.inputHandler.changeValue(to: "//1")
        presenter.validateSubstrate()
        XCTAssertEqual(view.substrateStatuses.last, .valid)
        view.substrateModel?.inputHandler.changeValue(to: "soft")
        presenter.validateSubstrate()
        XCTAssertEqual(view.substrateStatuses.last, .invalid)
        XCTAssertEqual(wireframe.errors.last as? AccountCreationError, .invalidDerivationHardSoftPassword)

        presenter.modalPickerDidSelectModelAtIndex(CryptoType.allCases.firstIndex(of: .ecdsa) ?? 2, context: nil)
        view.substrateModel?.inputHandler.changeValue(to: "/soft")
        presenter.validateSubstrate()
        XCTAssertEqual(wireframe.errors.last as? AccountCreationError, .invalidDerivationHardPassword)

        view.ethereumModel?.inputHandler.changeValue(to: "//44//60//0/0/0")
        presenter.validateEthereum()
        XCTAssertEqual(view.ethereumStatuses.last, .valid)
        view.ethereumModel?.inputHandler.changeValue(to: "//99999999999")
        presenter.validateEthereum()
        XCTAssertEqual(view.ethereumStatuses.last, .invalid)
        XCTAssertEqual(wireframe.errors.last as? AccountCreationError, .invalidDerivationHardSoftNumeric)
        XCTAssertEqual(wireframe.errors.count, 3)
    }

    func testWalletProceedConfirmsGeneratedWordsAndBackupShowsPasswordStep() throws {
        let (presenter, view, _, wireframe) = make()
        presenter.proceed(withReplaced: nil)
        XCTAssertTrue(wireframe.confirms.isEmpty, "No words yet")

        presenter.setup()
        presenter.didReceive(mnemonic: phrase.components(separatedBy: " "))
        XCTAssertEqual(view.mnemonics.last?.count, 12)
        view.substrateModel?.inputHandler.changeValue(to: "//1")

        presenter.proceed(withReplaced: nil)
        guard case let .wallet(request)? = wireframe.confirms.first else { return XCTFail("Expected a wallet confirmation") }
        XCTAssertEqual(request.username, "Fresh")
        XCTAssertEqual(request.substrateDerivationPath, "//1")
        XCTAssertEqual(request.ethereumDerivationPath, DerivationPathConstants.defaultEthereum)
        XCTAssertEqual(request.universalWalletEnrollment, .generated)
        XCTAssertEqual(request.mnemonic.toString(), phrase)

        presenter.didTapBackupButton()
        let backup = try XCTUnwrap(wireframe.backups.first)
        XCTAssertEqual(backup.username, "Fresh")
        XCTAssertEqual(backup.universalWalletEnrollment, .generated)
        XCTAssertEqual(wireframe.confirms.count, 1)
    }

    func testChainProceedUsesTheNetworkDerivationPath() throws {
        let substrate = CovJFixture.chain(name: "Kusama", addressPrefix: 2)
        let ethereum = CovJFixture.chain(name: "Moonbeam", options: [.ethereumBased])
        for chain in [substrate, ethereum] {
            let meta = wallet(cryptoType: 0)
            let (presenter, view, _, wireframe) = make(flow: .chain(model: UniqueChainModel(meta: meta, chain: chain)))
            presenter.setup()
            presenter.didReceive(mnemonic: phrase.components(separatedBy: " "))
            view.substrateModel?.inputHandler.changeValue(to: "//2")
            view.ethereumModel?.inputHandler.changeValue(to: "//44//60//0/0/1")

            presenter.proceed(withReplaced: nil)

            guard case let .chain(request)? = wireframe.confirms.first else { return XCTFail("Expected a chain confirmation") }
            XCTAssertEqual(request.chainId, chain.chainId)
            XCTAssertEqual(request.meta.metaId, meta.metaId)
            XCTAssertEqual(request.isEthereum, chain.isEthereumBased)
            XCTAssertEqual(request.derivationPath, chain.isEthereumBased ? "//44//60//0/0/1" : "//2")
            XCTAssertEqual(request.cryptoType, chain.isEthereumBased ? .ecdsa : .sr25519)
        }
    }

    func testProceedRejectsBadWordsAndBadPaths() {
        let (presenter, view, _, wireframe) = make()
        presenter.setup()
        presenter.didReceive(mnemonic: Array(repeating: "abandon", count: 12))
        presenter.proceed(withReplaced: nil)
        XCTAssertEqual(wireframe.errors.last as? AccountCreateError, .invalidMnemonicFormat)

        wireframe.handlesErrors = false
        presenter.didReceiveMnemonicGeneration(error: CovJError("entropy"))
        guard case .undefined? = wireframe.errors.last as? CommonError else { return XCTFail("Expected the undefined fallback") }

        wireframe.handlesErrors = true
        presenter.didReceive(mnemonic: phrase.components(separatedBy: " "))
        view.substrateModel?.inputHandler.changeValue(to: "soft")
        presenter.proceed(withReplaced: nil)
        XCTAssertEqual(view.substrateStatuses.last, .invalid)
        XCTAssertEqual(wireframe.errors.last as? AccountCreationError, .invalidDerivationHardSoftPassword)

        view.substrateModel?.inputHandler.changeValue(to: "")
        view.ethereumModel?.inputHandler.changeValue(to: "abc")
        presenter.proceed(withReplaced: nil)
        XCTAssertEqual(view.ethereumStatuses.last, .invalid)
        XCTAssertEqual(wireframe.errors.last as? AccountCreationError, .invalidDerivationHardSoftNumeric)
        XCTAssertTrue(wireframe.confirms.isEmpty)
    }
}

final class CovJAcctCreateModelTests: XCTestCase {
    func testAccountCreationErrorsHaveLocalizedContent() {
        let locale = CovJFixture.locale
        let languages = locale.rLanguages
        let pathTitle = R.string.localizable.commonInvalidPathTitle(preferredLanguages: languages)
        let expected: [(AccountCreationError, String, String)] = [
            (.unsupportedNetwork, R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
             R.string.localizable.commonUnsupportedNetworkMessage(preferredLanguages: languages)),
            (.invalidDerivationHardSoftNumericPassword, pathTitle,
             R.string.localizable.commonInvalidHardSoftNumericPasswordMessage(preferredLanguages: languages)),
            (.invalidDerivationHardSoftPassword, pathTitle, R.string.localizable.commonInvalidPathWithSoftMessage(preferredLanguages: languages)),
            (.invalidDerivationHardPassword, pathTitle, R.string.localizable.commonInvalidPathWithoutSoftMessage(preferredLanguages: languages)),
            (.invalidDerivationHardSoftNumeric, pathTitle, R.string.localizable.commonInvalidHardSoftNumericMessage(preferredLanguages: languages)),
            (.invalidDerivationHardSoft, pathTitle, R.string.localizable.commonInvalidHardSoftMessage(preferredLanguages: languages)),
            (.invalidDerivationHard, pathTitle, R.string.localizable.commonInvalidHardMessage(preferredLanguages: languages))
        ]
        for (error, title, message) in expected {
            let content = error.toErrorContent(for: locale)
            XCTAssertEqual(content.title, title, "\(error)")
            XCTAssertEqual(content.message, message, "\(error)")
            XCTAssertFalse(content.message.isEmpty)
        }
        XCTAssertEqual(AccountCreationError.invalidDerivationHard.toErrorContent(for: nil).title.isEmpty, false)
    }

    func testCreateFlowCapabilities() {
        let substrate = UniqueChainModel(meta: AccountGenerator.generateMetaAccount().replacingName("Named"), chain: CovJFixture.chain())
        let ethereum = UniqueChainModel(meta: substrate.meta, chain: CovJFixture.chain(options: [.ethereumBased]))
        let flows: [(AccountCreateFlow, Bool, Bool, Bool, String)] = [
            (.wallet, true, true, true, ""),
            (.backup, true, true, true, ""),
            (.chain(model: substrate), true, false, false, "Named"),
            (.chain(model: ethereum), false, true, false, "Named")
        ]
        for (flow, supportsSubstrate, supportsEthereum, supportsSelection, username) in flows {
            XCTAssertEqual(flow.supportsSubstrate, supportsSubstrate)
            XCTAssertEqual(flow.supportsEthereum, supportsEthereum)
            XCTAssertEqual(flow.supportsSelection, supportsSelection)
            XCTAssertEqual(flow.predefinedUsername, username)
        }
    }
}
