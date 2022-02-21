import Foundation
import SoraFoundation
import Rswift

enum AccountImportContext: String {
    case sourceType
    case cryptoType
}

// TODO: 1. Create MetaAccountImport scene
// TODO: 2. Create ChainAccountImport scene
// Can we inherit from a base?

final class AccountImportPresenter {
    static let maxMnemonicLength: Int = 250
    static let maxMnemonicSize: Int = 24
    static let maxRawSeedLength: Int = 66
    static let maxKeystoreLength: Int = 4000

    weak var view: AccountImportViewProtocol?
    var wireframe: AccountImportWireframeProtocol!
    var interactor: AccountImportInteractorInputProtocol!

    private(set) var metadata: MetaAccountImportMetadata?

    private(set) var selectedSourceType: AccountImportSource?
    private(set) var selectedCryptoType: CryptoType?

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var substrateDerivationPathViewModel: InputViewModelProtocol?
    private(set) var ethereumDerivationPathViewModel: InputViewModelProtocol?

    private lazy var jsonDeserializer = JSONSerialization()

    private func applySourceType(_ value: String = "", preferredInfo: MetaAccountImportPreferredInfo? = nil) {
        guard let selectedSourceType = selectedSourceType, let metadata = metadata else {
            return
        }

        if let preferredInfo = preferredInfo {
            selectedCryptoType = preferredInfo.cryptoType
        } else {
            selectedCryptoType = selectedCryptoType ?? metadata.defaultCryptoType
        }

        view?.setSource(type: selectedSourceType)

        applySourceTextViewModel(value)

        let username = preferredInfo?.username ?? ""
        applyUsernameViewModel(username)
        applyPasswordViewModel()
        applyAdvanced(preferredInfo)

        if let preferredInfo = preferredInfo {
            showUploadWarningIfNeeded(preferredInfo)
        }
    }

    private func applySourceTextViewModel(_ value: String = "") {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        let viewModel: InputViewModelProtocol

        let locale = localizationManager?.selectedLocale ?? Locale.current

        switch selectedSourceType {
        case .mnemonic:
            let placeholder = R.string.localizable
                .importMnemonic(preferredLanguages: locale.rLanguages)
            let normalizer = MnemonicTextNormalizer()
            let inputHandler = InputHandler(
                value: value,
                maxLength: AccountImportPresenter.maxMnemonicLength,
                validCharacterSet: CharacterSet.englishMnemonic,
                predicate: NSPredicate.notEmpty,
                normalizer: normalizer
            )
            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)
        case .seed:
            let placeholder = R.string.localizable
                .accountImportRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
            let inputHandler = InputHandler(
                value: value,
                maxLength: Self.maxRawSeedLength,
                predicate: NSPredicate.seed
            )
            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)
        case .keystore:
            let placeholder = R.string.localizable
                .accountImportRecoveryJsonPlaceholder(preferredLanguages: locale.rLanguages)
            let inputHandler = InputHandler(
                value: value,
                maxLength: Self.maxKeystoreLength,
                predicate: NSPredicate.notEmpty
            )
            viewModel = InputViewModel(
                inputHandler: inputHandler,
                placeholder: placeholder
            )
        }

        sourceViewModel = viewModel

        view?.setSource(viewModel: viewModel)
    }

    private func applyUsernameViewModel(_ username: String = "") {
        let processor = ByteLengthProcessor.username
        let processedUsername = processor.process(text: username)

        let inputHandler = InputHandler(
            value: processedUsername,
            predicate: NSPredicate.notEmpty,
            processor: processor
        )

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

    private func showUploadWarningIfNeeded(_ preferredInfo: MetaAccountImportPreferredInfo) {
        guard let metadata = metadata else {
            return
        }

        if preferredInfo.networkType == nil {
            let locale = localizationManager?.selectedLocale
            let message = R.string.localizable.accountImportJsonNoNetwork(preferredLanguages: locale?.rLanguages)
            view?.setUploadWarning(message: message)
            return
        }

        if let preferredNetwork = preferredInfo.networkType,
           !metadata.availableNetworks.contains(preferredNetwork) {
            let locale = localizationManager?.selectedLocale ?? Locale.current
            let message = R.string.localizable
                .accountImportWrongNetwork(
                    preferredNetwork.titleForLocale(locale),
                    metadata.defaultNetwork.titleForLocale(locale)
                )
            view?.setUploadWarning(message: message)
            return
        }
    }

    private func applyAdvanced(_ preferredInfo: MetaAccountImportPreferredInfo?) {
        guard let selectedSourceType = selectedSourceType else {
            let locale = localizationManager?.selectedLocale
            let warning = R.string.localizable.accountImportJsonNoNetwork(preferredLanguages: locale?.rLanguages)
            view?.setUploadWarning(message: warning)
            return
        }

        switch selectedSourceType {
        case .mnemonic, .seed:
            applyCryptoTypeViewModel(preferredInfo)
            applySubstrateDerivationPathViewModel()
            applyEthereumDerivationPathViewModel()
        case .keystore:
            applyCryptoTypeViewModel(preferredInfo)
            substrateDerivationPathViewModel = nil
            ethereumDerivationPathViewModel = nil
        }
    }

    private func applyCryptoTypeViewModel(_ preferredInfo: MetaAccountImportPreferredInfo?) {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let viewModel = TitleWithSubtitleViewModel(
            title: cryptoType.titleForLocale(locale),
            subtitle: cryptoType.subtitleForLocale(locale)
        )

        let selectable: Bool

        if preferredInfo?.cryptoType != nil {
            selectable = false
        } else {
            selectable = (metadata?.availableCryptoTypes.count ?? 0) > 1
        }

        view?.setSelectedCrypto(model: SelectableViewModel(
            underlyingViewModel: viewModel,
            selectable: selectable
        ))
    }

    private func applySubstrateDerivationPathViewModel() {
        guard let cryptoType = selectedCryptoType, let sourceType = selectedSourceType else {
            return
        }

        let viewModel = createViewModel(
            for: cryptoType,
            sourceType: sourceType,
            isEthereum: false
        )

        substrateDerivationPathViewModel = viewModel

        view?.bind(substrateViewModel: viewModel)
        view?.didValidateSubstrateDerivationPath(.none)
    }

    private func applyEthereumDerivationPathViewModel() {
        guard let sourceType = selectedSourceType else {
            return
        }

        let viewModel = createViewModel(
            for: .ecdsa,
            sourceType: sourceType,
            isEthereum: true
        )

        ethereumDerivationPathViewModel = viewModel

        view?.bind(ethereumViewModel: viewModel)
        view?.didValidateEthereumDerivationPath(.none)
    }

    private func createViewModel(
        for cryptoType: CryptoType,
        sourceType: AccountImportSource,
        isEthereum: Bool
    ) -> InputViewModel {
        let predicate: NSPredicate
        let placeholder: String
        if isEthereum {
            switch (cryptoType, sourceType) {
            case (_, .mnemonic):
                predicate = NSPredicate.deriviationPathHardPassword
                placeholder = DerivationPathConstants.defaultEthereum
            default:
                predicate = NSPredicate.deriviationPathHard
                placeholder = DerivationPathConstants.defaultEthereum
            }
        } else {
            switch (cryptoType, sourceType) {
            case (.sr25519, .mnemonic):
                predicate = NSPredicate.deriviationPathHardSoftPassword
                placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder
            case (.sr25519, _):
                predicate = NSPredicate.deriviationPathHardSoft
                placeholder = DerivationPathConstants.hardSoftPlaceholder
            case (_, .mnemonic):
                predicate = NSPredicate.deriviationPathHardPassword
                placeholder = DerivationPathConstants.hardPasswordPlaceholder
            case (_, _):
                predicate = NSPredicate.deriviationPathHard
                placeholder = DerivationPathConstants.hardPasswordPlaceholder
            }
        }

        let inputHandling = InputHandler(required: false, predicate: predicate)
        return InputViewModel(inputHandler: inputHandling, placeholder: placeholder)
    }

    private func presentDerivationPathError(
        sourceType: AccountImportSource,
        cryptoType: CryptoType,
        isEthereum: Bool
    ) {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let error: AccountCreationError

        if isEthereum {
            error = sourceType == .mnemonic ?
                .invalidDerivationHardSoftNumericPassword : .invalidDerivationHardSoftNumeric
        } else {
            switch cryptoType {
            case .sr25519:
                error = sourceType == .mnemonic ?
                    .invalidDerivationHardSoftPassword : .invalidDerivationHardSoft

            case .ed25519, .ecdsa:
                error = sourceType == .mnemonic ?
                    .invalidDerivationHardPassword : .invalidDerivationHard
            }
        }

        _ = wireframe.present(error: error, from: view, locale: locale)
    }

    func validateSourceViewModel() -> Error? {
        guard let viewModel = sourceViewModel, let selectedSourceType = selectedSourceType else {
            return nil
        }

        switch selectedSourceType {
        case .mnemonic:
            return validateMnemonic(value: viewModel.inputHandler.normalizedValue)
        case .seed:
            return viewModel.inputHandler.completed ? nil : AccountCreateError.invalidSeed
        case .keystore:
            return validateKeystore(value: viewModel.inputHandler.value)
        }
    }

    func validateMnemonic(value: String) -> Error? {
        let mnemonicSize = value.components(separatedBy: CharacterSet.whitespaces).count
        return mnemonicSize > AccountImportPresenter.maxMnemonicSize ?
            AccountCreateError.invalidMnemonicSize : nil
    }

    func validateKeystore(value: String) -> Error? {
        guard let data = value.data(using: .utf8) else {
            return AccountCreateError.invalidKeystore
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return nil
        } catch {
            return AccountCreateError.invalidKeystore
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

            wireframe.presentSourceTypeSelection(
                from: view,
                availableSources: metadata.availableSources,
                selectedSource: selectedSourceType,
                delegate: self,
                context: context
            )
        }
    }

    func selectCryptoType() {
        if let metadata = metadata {
            let context = AccountImportContext.cryptoType.rawValue as NSString
            let selectedType = selectedCryptoType ?? metadata.defaultCryptoType
            wireframe.presentCryptoTypeSelection(
                from: view,
                availableTypes: metadata.availableCryptoTypes,
                selectedType: selectedType,
                delegate: self,
                context: context
            )
        }
    }

    func activateUpload() {
        let locale = localizationManager?.selectedLocale

        let pasteTitle = R.string.localizable
            .accountImportRecoveryJsonPlaceholder(preferredLanguages: locale?.rLanguages)
        let pasteAction = AlertPresentableAction(title: pasteTitle) { [weak self] in
            if let json = UIPasteboard.general.string {
                self?.interactor.deriveMetadataFromKeystore(json)
            }
        }

        let title = R.string.localizable.importRecoveryJson(preferredLanguages: locale?.rLanguages)
        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [pasteAction],
            closeAction: closeTitle
        )

        wireframe.present(viewModel: viewModel, style: .actionSheet, from: view)
    }

    func validateSubstrateDerivationPath() {
        guard let viewModel = substrateDerivationPathViewModel,
              let cryptoType = selectedCryptoType,
              let sourceType = selectedSourceType
        else {
            return
        }

        if viewModel.inputHandler.completed {
            view?.didValidateSubstrateDerivationPath(.valid)
        } else {
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(
                sourceType: sourceType,
                cryptoType: cryptoType,
                isEthereum: false
            )
        }
    }

    func validateEthereumDerivationPath() {
        guard let viewModel = ethereumDerivationPathViewModel,
              let sourceType = selectedSourceType
        else {
            return
        }

        if viewModel.inputHandler.completed {
            view?.didValidateEthereumDerivationPath(.valid)
        } else {
            view?.didValidateEthereumDerivationPath(.invalid)
            presentDerivationPathError(
                sourceType: sourceType,
                cryptoType: .ecdsa,
                isEthereum: true
            )
        }
    }

    func proceed() {
        guard
            let selectedSourceType = selectedSourceType,
            let selectedCryptoType = selectedCryptoType,
            let sourceViewModel = sourceViewModel,
            let usernameViewModel = usernameViewModel
        else {
            return
        }

        if let error = validateSourceViewModel() {
            _ = wireframe.present(
                error: error,
                from: view,
                locale: localizationManager?.selectedLocale
            )
            return
        }

        if
            let substrateDerivationPathViewModel = substrateDerivationPathViewModel,
            !substrateDerivationPathViewModel.inputHandler.completed {
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(
                sourceType: selectedSourceType,
                cryptoType: selectedCryptoType,
                isEthereum: false
            )
            return
        }

        if
            let ethereumDerivationPathViewModel = ethereumDerivationPathViewModel,
            !ethereumDerivationPathViewModel.inputHandler.completed {
            view?.didValidateEthereumDerivationPath(.invalid)
            presentDerivationPathError(
                sourceType: selectedSourceType,
                cryptoType: selectedCryptoType,
                isEthereum: true
            )
            return
        }

        let username = usernameViewModel.inputHandler.value
        let password = passwordViewModel?.inputHandler.value ?? ""
        let substrateDerivationPath = (substrateDerivationPathViewModel?.inputHandler.value).nonEmpty(or: "")
        let ethereumDerivationPath =
            (ethereumDerivationPathViewModel?.inputHandler.value).nonEmpty(or: DerivationPathConstants.defaultEthereum)

        switch selectedSourceType {
        case .mnemonic:
            let mnemonic = sourceViewModel.inputHandler.normalizedValue

            let request = MetaAccountImportMnemonicRequest(
                mnemonic: mnemonic,
                username: username,
                substrateDerivationPath: substrateDerivationPath,
                ethereumDerivationPath: ethereumDerivationPath,
                cryptoType: selectedCryptoType
            )
            interactor.importAccountWithMnemonic(request: request)
        case .seed:
            let seed = sourceViewModel.inputHandler.value
            let request = MetaAccountImportSeedRequest(
                seed: seed,
                username: username,
                substrateDerivationPath: substrateDerivationPath,
                ethereumDerivationPath: ethereumDerivationPath,
                cryptoType: selectedCryptoType
            )
            interactor.importAccountWithSeed(request: request)
        case .keystore:
            let keystore = sourceViewModel.inputHandler.value
            let request = MetaAccountImportKeystoreRequest(
                keystore: keystore,
                password: password,
                username: username,
                cryptoType: selectedCryptoType
            )

            interactor.importAccountWithKeystore(request: request)
        }
    }
}

private extension Optional where Wrapped == String {
    func nonEmpty(or defaultValue: String) -> String {
        guard let self = self, !self.isEmpty else {
            return defaultValue
        }

        return self
    }
}

extension AccountImportPresenter: AccountImportInteractorOutputProtocol {
    func didReceiveAccountImport(metadata: MetaAccountImportMetadata) {
        self.metadata = metadata

        selectedSourceType = metadata.defaultSource
        selectedCryptoType = metadata.defaultCryptoType

        applySourceType()
    }

    func didCompleteAccountImport() {
        wireframe.proceed(from: view)
    }

    func didReceiveAccountImport(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(
            error: CommonError.undefined,
            from: view,
            locale: locale
        )
    }

    func didSuggestKeystore(text: String, preferredInfo: MetaAccountImportPreferredInfo?) {
        selectedSourceType = .keystore

        applySourceType(text, preferredInfo: preferredInfo)
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

                selectedCryptoType = metadata?.defaultCryptoType

                applySourceType()

                view?.didCompleteSourceTypeSelection()
            case .cryptoType:
                selectedCryptoType = metadata?.availableCryptoTypes[index]

                applyCryptoTypeViewModel(nil)
                applySubstrateDerivationPathViewModel()

                view?.didCompleteCryptoTypeSelection()
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
            }
        }
    }
}

extension AccountImportPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applySourceType()
        }
    }
}
