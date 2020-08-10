import Foundation
import IrohaCrypto
import SoraFoundation

enum AccountImportContext: String {
    case sourceType
    case cryptoType
    case addressType
}

final class AccountImportPresenter {
    static let maxMnemonicLength: Int = 250
    static let maxMnemonicSize: Int = 24
    static let maxRawSeedLength: Int = 66

    weak var view: AccountImportViewProtocol?
    var wireframe: AccountImportWireframeProtocol!
    var interactor: AccountImportInteractorInputProtocol!

    private(set) var metadata: AccountImportMetadata?

    private(set) var selectedSourceType: AccountImportSource?
    private(set) var selectedCryptoType: CryptoType?
    private(set) var selectedAddressType: SNAddressType?

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var derivationPathViewModel: InputViewModelProtocol?

    private lazy var jsonDeserializer = JSONSerialization()

    private func applySourceType() {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        view?.setSource(type: selectedSourceType)

        applySourceTextViewModel()
        applyUsernameViewModel()
        applyPasswordViewModel()
        applyAdvanced()
    }

    private func applySourceTextViewModel() {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        let viewModel: InputViewModelProtocol

        let locale = localizationManager?.selectedLocale ?? Locale.current

        sourceViewModel?.inputHandler.removeObserver(self)

        switch selectedSourceType {
        case .mnemonic:
            let placeholder = R.string.localizable
                .importMnemonic(preferredLanguages: locale.rLanguages)
            let inputHandler = InputHandler(maxLength: AccessRestorePresenter.maxMnemonicLength,
                                            validCharacterSet: CharacterSet.englishMnemonic,
                                            predicate: NSPredicate.notEmpty)
            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)
        case .seed:
            let placeholder = R.string.localizable
                .accountImportRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
            let inputHandler = InputHandler(predicate: NSPredicate.seed)
            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)
        case .keystore:
            let placeholder = R.string.localizable
                .accountImportRecoveryJsonPlaceholder(preferredLanguages: locale.rLanguages)
            let inputHandler = InputHandler(predicate: NSPredicate.notEmpty)
            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)
            viewModel.inputHandler.addObserver(self)
        }

        sourceViewModel = viewModel

        view?.setSource(viewModel: viewModel)
    }

    private func applyUsernameViewModel(_ username: String = "") {
        let inputHandler = InputHandler(value: username, predicate: NSPredicate.notEmpty)
        let viewModel = InputViewModel(inputHandler: inputHandler)
        usernameViewModel = viewModel

        view?.setName(viewModel: viewModel)
    }

    private func applyPasswordViewModel() {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        switch selectedSourceType {
        case .mnemonic, .seed:
            passwordViewModel = nil
        case .keystore:
            let viewModel = InputViewModel(inputHandler: InputHandler(required: false))
            passwordViewModel = viewModel

            view?.setPassword(viewModel: viewModel)
        }
    }

    private func applyAdvanced() {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        switch selectedSourceType {
        case .mnemonic, .seed:
            applyCryptoTypeViewModel()
            applyDerivationPathViewModel()
            applyAddressTypeViewModel()
        case .keystore:
            derivationPathViewModel = nil
        }
    }

    private func applyCryptoTypeViewModel() {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let viewModel = TitleWithSubtitleViewModel(title: cryptoType.titleForLocale(locale),
                                                   subtitle: cryptoType.subtitleForLocale(locale))

        view?.setSelectedCrypto(model: viewModel)
    }

    private func applyAddressTypeViewModel() {
        guard let addressType = selectedAddressType else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let viewModel = IconWithTitleViewModel(icon: addressType.icon,
                                               title: addressType.titleForLocale(locale))

        view?.setSelectedNetwork(model: viewModel)
    }

    private func applyDerivationPathViewModel() {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let predicate: NSPredicate
        let placeholder: String

        if cryptoType == .sr25519 {
            predicate = NSPredicate.deriviationPath
            placeholder = DerivationPathConstants.fullPlaceholder
        } else {
            predicate = NSPredicate.deriviationPathWithoutSoft
            placeholder = DerivationPathConstants.withoutSoftPlaceholder
        }

        let inputHandling = InputHandler(required: false, predicate: predicate)

        let viewModel = InputViewModel(inputHandler: inputHandling,
                                       placeholder: placeholder)

        self.derivationPathViewModel = viewModel

        view?.setDerivationPath(viewModel: viewModel)
        view?.didValidateDerivationPath(.none)
    }

    private func presentDerivationPathError(_ cryptoType: CryptoType) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        switch cryptoType {
        case .sr25519:
            _ = wireframe.present(error: AccountCreationError.invalidDerivationPath,
                                  from: view,
                                  locale: locale)
        case .ed25519, .ecdsa:
            _ = wireframe.present(error: AccountCreationError.invalidDerivationPathWithoutSoft,
                                  from: view,
                                  locale: locale)
        }
    }

    func validateSourceViewModel() -> Error? {
        guard let viewModel = sourceViewModel, let selectedSourceType = selectedSourceType else {
            return nil
        }

        switch selectedSourceType {
        case .mnemonic:
            return validateMnemonic(value: viewModel.inputHandler.value)
        case .seed:
            return viewModel.inputHandler.completed ? nil : AccountImportError.invalidSeed
        case .keystore:
            return validateKeystore(value: viewModel.inputHandler.value)
        }
    }

    func validateMnemonic(value: String) -> Error? {
        let mnemonicSize = value.components(separatedBy: CharacterSet.whitespaces).count
        return mnemonicSize > AccessRestorePresenter.mnemonicSize ?
            AccountImportError.invalidMnemonicSize : nil
    }

    func validateKeystore(value: String) -> Error? {
        guard let data = value.data(using: .utf8) else {
            return AccountImportError.invalidKeystore
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return nil
        } catch {
            return AccountImportError.invalidKeystore
        }
    }
}

extension AccountImportPresenter: AccountImportPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectSourceType() {
        if let metadata = metadata {
            let context = AccountImportContext.sourceType.rawValue as NSString
            let selectedSourceType = self.selectedSourceType ?? metadata.defaultSource

            wireframe.presentSourceTypeSelection(from: view,
                                                 availableSources: metadata.availableSources,
                                                 selectedSource: selectedSourceType,
                                                 delegate: self,
                                                 context: context)
        }
    }

    func selectCryptoType() {
        if let metadata = metadata {
            let context = AccountImportContext.cryptoType.rawValue as NSString
            let selectedType = selectedCryptoType ?? metadata.defaultCryptoType
            wireframe.presentCryptoTypeSelection(from: view,
                                                 availableTypes: metadata.availableCryptoTypes,
                                                 selectedType: selectedType,
                                                 delegate: self,
                                                 context: context)
        }
    }

    func selectAddressType() {
        if let metadata = metadata {
            let context = AccountImportContext.addressType.rawValue as NSString
            let selectedType = selectedAddressType ?? metadata.defaultAddressType
            wireframe.presentAddressTypeSelection(from: view,
                                                  availableTypes: metadata.availableAddressTypes,
                                                  selectedType: selectedType,
                                                  delegate: self,
                                                  context: context)
        }
    }

    func activateQrScan() {}

    func validateDerivationPath() {
        guard let viewModel = derivationPathViewModel, let cryptoType = selectedCryptoType else {
            return
        }

        if viewModel.inputHandler.completed {
            view?.didValidateDerivationPath(.valid)
        } else {
            view?.didValidateDerivationPath(.invalid)
            presentDerivationPathError(cryptoType)
        }
    }

    func proceed() {
        guard
            let selectedSourceType = selectedSourceType,
            let selectedCryptoType = selectedCryptoType,
            let sourceViewModel = sourceViewModel,
            let usernameViewModel = usernameViewModel,
            let metadata = metadata else {
            return
        }

        if let error = validateSourceViewModel() {
            _ = wireframe.present(error: error,
                                  from: view,
                                  locale: localizationManager?.selectedLocale)
            return
        }

        if
            let derivationPathViewModel = derivationPathViewModel,
            !derivationPathViewModel.inputHandler.completed {
            view?.didValidateDerivationPath(.invalid)
            presentDerivationPathError(selectedCryptoType)
            return
        }

        switch selectedSourceType {
        case .mnemonic:
            let mnemonic = sourceViewModel.inputHandler.value
            let username = usernameViewModel.inputHandler.value
            let addressType = selectedAddressType ?? metadata.defaultAddressType
            let derivationPath = derivationPathViewModel?.inputHandler.value ?? ""
            let request = AccountImportMnemonicRequest(mnemonic: mnemonic,
                                                       username: username,
                                                       type: addressType,
                                                       derivationPath: derivationPath,
                                                       cryptoType: selectedCryptoType)
            interactor.importAccountWithMnemonic(request: request)
        case .seed:
            let seed = sourceViewModel.inputHandler.value
            let username = usernameViewModel.inputHandler.value
            let addressType = selectedAddressType ?? metadata.defaultAddressType
            let derivationPath = derivationPathViewModel?.inputHandler.value ?? ""
            let request = AccountImportSeedRequest(seed: seed,
                                                   username: username,
                                                   type: addressType,
                                                   derivationPath: derivationPath,
                                                   cryptoType: selectedCryptoType)
            interactor.importAccountWithSeed(request: request)
        case .keystore:
            let keystore = sourceViewModel.inputHandler.value
            let password = passwordViewModel?.inputHandler.value ?? ""
            let username = usernameViewModel.inputHandler.value
            let request = AccountImportKeystoreRequest(keystore: keystore,
                                                       password: password,
                                                       username: username)
            interactor.importAccountWithKeystore(request: request)
        }
    }
}

extension AccountImportPresenter: AccountImportInteractorOutputProtocol {
    func didReceiveAccountImport(metadata: AccountImportMetadata) {
        self.metadata = metadata

        selectedSourceType = metadata.defaultSource
        selectedCryptoType = metadata.defaultCryptoType
        selectedAddressType = metadata.defaultAddressType

        applySourceType()
    }

    func didCompleAccountImport() {
        wireframe.proceed(from: view)
    }

    func didReceiveAccountImport(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(error: CommonError.undefined,
                              from: view,
                              locale: locale)
    }

    func didDeriveKeystore(username: String) {
        applyUsernameViewModel(username)
    }
}

extension AccountImportPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        if
            let context = context as? NSString,
            let selectionContext = AccountImportContext(rawValue: context as String) {
            switch selectionContext {
            case .sourceType:
                selectedSourceType = metadata?.availableSources[index]

                applySourceType()

                view?.didCompleteSourceTypeSelection()
            case .cryptoType:
                selectedCryptoType = metadata?.availableCryptoTypes[index]

                applyCryptoTypeViewModel()
                applyDerivationPathViewModel()

                view?.didCompleteCryptoTypeSelection()
            case .addressType:
                selectedAddressType = metadata?.availableAddressTypes[index]

                applyAddressTypeViewModel()
                view?.didCompleteAddressTypeSelection()
            }
        }
    }

    func modalPickerDidCancel(context: AnyObject?) {
        if
            let context = context as? NSString,
            let selectionContext = AccountImportContext(rawValue: context as String) {
            switch selectionContext {
            case .sourceType:
                view?.didCompleteSourceTypeSelection()
            case .cryptoType:
                view?.didCompleteCryptoTypeSelection()
            case .addressType:
                view?.didCompleteAddressTypeSelection()
            }
        }
    }
}

extension AccountImportPresenter: InputHandlingObserver {
    func didChangeInputValue(_ handler: InputHandling, from oldValue: String) {
        guard
            let selectedSourceType = selectedSourceType,
            selectedSourceType == .keystore,
            validateKeystore(value: handler.value) == nil else {
            return
        }

        if let usernameViewModel = usernameViewModel, !usernameViewModel.inputHandler.value.isEmpty {
            return
        }

        interactor.deriveUsernameFromKeystore(handler.value)
    }
}

extension AccountImportPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applySourceType()
        }
    }
}
