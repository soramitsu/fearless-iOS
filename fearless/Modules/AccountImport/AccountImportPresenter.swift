import Foundation
import SoraFoundation
import Rswift
import FearlessUtils

enum AccountImportContext: String {
    case sourceType
    case cryptoType
}

struct PreferredData {
    let sourceType: AccountImportSource?
    let source: String?
    let username: String?
    let password: String?
    let cryptoType: CryptoType?
    let derivationPath: String?

    init(stepData: AccountCreationStep.FirstStepData) {
        sourceType = stepData.sourceType
        source = stepData.source
        username = stepData.username
        password = stepData.password
        cryptoType = stepData.cryptoType
        derivationPath = stepData.derivationPath
    }

    init(jsonData: MetaAccountImportPreferredInfo?) {
        sourceType = nil
        source = nil
        username = jsonData?.username
        password = nil
        cryptoType = jsonData?.cryptoType
        derivationPath = nil
    }
}

// TODO: 1. Create MetaAccountImport scene
// TODO: 2. Create ChainAccountImport scene
// Can we inherit from a base?

final class AccountImportPresenter: NSObject {
    static let maxMnemonicLength: Int = 250
    static let maxMnemonicSize: Int = 24
    static let maxRawSeedLength: Int = 66
    static let maxKeystoreLength: Int = 4000
    static let ethereumDerivationPathLength: Int = 15

    weak var view: AccountImportViewProtocol?
    var wireframe: AccountImportWireframeProtocol
    var interactor: AccountImportInteractorInputProtocol

    private let step: AccountCreationStep
    private(set) var metadata: MetaAccountImportMetadata?

    private(set) var selectedSourceType: AccountImportSource?
    private(set) var selectedCryptoType: CryptoType?

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var substrateDerivationPathViewModel: InputViewModelProtocol?
    private(set) var ethereumDerivationPathViewModel: InputViewModelProtocol?

    private lazy var jsonDeserializer = JSONSerialization()

    init(
        wireframe: AccountImportWireframeProtocol,
        interactor: AccountImportInteractorInputProtocol,
        step: AccountCreationStep = .first
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.step = step
    }

    func applySourceType(
        _ value: String = "",
        preferredData: PreferredData? = nil
    ) {
        guard let selectedSourceType = selectedSourceType, let metadata = metadata else {
            return
        }

        if let data = preferredData {
            selectedCryptoType = data.cryptoType
            view?.setSource(type: selectedSourceType, selectable: false)
        } else {
            selectedCryptoType = selectedCryptoType ?? metadata.defaultCryptoType
            view?.setSource(type: selectedSourceType, selectable: true)
        }

        applySourceTextViewModel(value)

        let username = preferredData?.username ?? ""
        applyUsernameViewModel(username)
        applyPasswordViewModel()
        applyAdvanced(preferredData?.cryptoType)
    }

    func applySourceTextViewModel(_ value: String = "") {
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
            var placeholder: String
            switch step {
            case .first:
                placeholder = R.string.localizable
                    .accountImportSubstrateRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
            case .second:
                placeholder = R.string.localizable
                    .accountImportEthereumRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
            }
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

    func applyUsernameViewModel(_ username: String = "") {
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

    func applyPasswordViewModel() {
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

    func applyAdvanced(_ cryptoType: CryptoType?) {
        guard let selectedSourceType = selectedSourceType else {
            let locale = localizationManager?.selectedLocale
            let warning = R.string.localizable.accountImportJsonNoNetwork(preferredLanguages: locale?.rLanguages)
            view?.setUploadWarning(message: warning)
            return
        }

        switch selectedSourceType {
        case .mnemonic:
            applyCryptoTypeViewModel(cryptoType)
            applySubstrateDerivationPathViewModel()
            applyEthereumDerivationPathViewModel()
            view?.show(chainType: .both)
        case .seed:
            applyCryptoTypeViewModel(cryptoType)
            switch step {
            case .first:
                applySubstrateDerivationPathViewModel()
                view?.show(chainType: .substrate)
            case .second:
                applyEthereumDerivationPathViewModel()
                view?.show(chainType: .ethereum)
            }
        case .keystore:
            applyCryptoTypeViewModel(cryptoType)
            substrateDerivationPathViewModel = nil
            ethereumDerivationPathViewModel = nil
        }
    }

    func applyCryptoTypeViewModel(_ preselectedCryptoType: CryptoType? = nil) {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let viewModel = TitleWithSubtitleViewModel(
            title: cryptoType.titleForLocale(locale),
            subtitle: cryptoType.subtitleForLocale(locale)
        )

        let selectable: Bool

        if preselectedCryptoType != nil {
            selectable = false
        } else {
            selectable = (metadata?.availableCryptoTypes.count ?? 0) > 1
        }

        view?.setSelectedCrypto(model: SelectableViewModel(
            underlyingViewModel: viewModel,
            selectable: selectable
        ))
    }

    func applySubstrateDerivationPathViewModel() {
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

    func applyEthereumDerivationPathViewModel() {
        guard let sourceType = selectedSourceType else {
            return
        }
        let processor = EthereumDerivationPathProcessor()

        let viewModel = createViewModel(
            for: .ecdsa,
            sourceType: sourceType,
            isEthereum: true,
            processor: processor,
            maxLength: AccountImportPresenter.ethereumDerivationPathLength
        )

        ethereumDerivationPathViewModel = viewModel

        view?.bind(ethereumViewModel: viewModel)
        view?.didValidateEthereumDerivationPath(.none)
    }

    func createViewModel(
        for cryptoType: CryptoType,
        sourceType: AccountImportSource,
        isEthereum: Bool,
        processor: TextProcessing? = nil,
        maxLength: Int? = nil
    ) -> InputViewModel {
        let predicate: NSPredicate?
        let placeholder: String
        if isEthereum {
            predicate = NSPredicate.deriviationPathHardSoftNumeric
            placeholder = DerivationPathConstants.defaultEthereum
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

        let inputHandling = InputHandler(
            required: false,
            maxLength: maxLength ?? Int.max,
            predicate: predicate,
            processor: processor
        )
        return InputViewModel(inputHandler: inputHandling, placeholder: placeholder)
    }

    func presentDerivationPathError(
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

    func askIfNeedAddEthereum(showHandler: @escaping () -> Void, closeHandler: @escaping () -> Void) {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let showAction = AlertPresentableAction(
            title: R.string.localizable.commonYes(preferredLanguages: locale.rLanguages),
            handler: showHandler
        )
        let closeAction = AlertPresentableAction(
            title: R.string.localizable.commonNo(preferredLanguages: locale.rLanguages),
            handler: closeHandler
        )
        let alertViewModel = AlertPresentableViewModel(
            title: R.string.localizable.alertAddEthereumTitle(preferredLanguages: locale.rLanguages),
            message: R.string.localizable.alertAddEthereumMessage(preferredLanguages: locale.rLanguages),
            actions: [showAction, closeAction],
            closeAction: nil
        )
        wireframe.present(viewModel: alertViewModel, style: .alert, from: view)
    }

    func createAccount(
        sourceViewModel: InputViewModelProtocol,
        username: String,
        substrateDerivationPath: String,
        ethereumDerivationPath: String,
        selectedCryptoType: CryptoType,
        password: String,
        selectedSourceType: AccountImportSource
    ) {
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
            switch step {
            case .first:
                askIfNeedAddEthereum { [weak self] in
                    guard let self = self else { return }
                    let data = AccountCreationStep.FirstStepData(
                        sourceType: .seed,
                        source: sourceViewModel.inputHandler.value,
                        username: username,
                        password: password,
                        cryptoType: selectedCryptoType,
                        derivationPath: substrateDerivationPath
                    )
                    self.wireframe.showSecondStep(from: self.view, with: data)
                } closeHandler: { [weak self] in
                    guard let self = self else { return }
                    let seed = sourceViewModel.inputHandler.value
                    let request = MetaAccountImportSeedRequest(
                        substrateSeed: seed,
                        ethereumSeed: nil,
                        username: username,
                        substrateDerivationPath: substrateDerivationPath,
                        ethereumDerivationPath: nil,
                        cryptoType: selectedCryptoType
                    )
                    self.interactor.importAccountWithSeed(request: request)
                }
            case let .second(data):
                let seed = sourceViewModel.inputHandler.value
                let request = MetaAccountImportSeedRequest(
                    substrateSeed: data.source,
                    ethereumSeed: seed,
                    username: username,
                    substrateDerivationPath: substrateDerivationPath,
                    ethereumDerivationPath: ethereumDerivationPath,
                    cryptoType: selectedCryptoType
                )
                interactor.importAccountWithSeed(request: request)
            }
        case .keystore:
            switch step {
            case .first:
                askIfNeedAddEthereum { [weak self] in
                    guard let self = self else { return }
                    let data = AccountCreationStep.FirstStepData(
                        sourceType: .keystore,
                        source: sourceViewModel.inputHandler.value,
                        username: username,
                        password: password,
                        cryptoType: selectedCryptoType,
                        derivationPath: substrateDerivationPath
                    )
                    self.wireframe.showSecondStep(from: self.view, with: data)
                } closeHandler: { [weak self] in
                    guard let self = self else { return }
                    let keystore = sourceViewModel.inputHandler.value
                    let request = MetaAccountImportKeystoreRequest(
                        substrateKeystore: keystore,
                        ethereumKeystore: nil,
                        substratePassword: password,
                        ethereumPassword: nil,
                        username: username,
                        cryptoType: selectedCryptoType
                    )
                    self.interactor.importAccountWithKeystore(request: request)
                }
            case let .second(data):
                let keystore = sourceViewModel.inputHandler.value
                let request = MetaAccountImportKeystoreRequest(
                    substrateKeystore: data.source,
                    ethereumKeystore: keystore,
                    substratePassword: data.password,
                    ethereumPassword: password,
                    username: username,
                    cryptoType: data.cryptoType
                )

                interactor.importAccountWithKeystore(request: request)
            }
        }
    }
}

extension AccountImportPresenter: AccountImportPresenterProtocol {
    func setup() {
        interactor.setup()
        if case let .second(data) = step {
            selectedSourceType = data.sourceType
            selectedCryptoType = data.cryptoType
            applySourceType(preferredData: PreferredData(stepData: data))
            applyCryptoTypeViewModel(data.cryptoType)
        }
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
        let selectFileTitle = R.string.localizable
            .accountImportRecoverySelectFile(preferredLanguages: locale?.rLanguages)
        let selectFileAction = AlertPresentableAction(title: selectFileTitle) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.wireframe.presentSelectFilePicker(
                from: strongSelf.view,
                delegate: strongSelf
            )
        }

        let title = R.string.localizable.importRecoveryJson(preferredLanguages: locale?.rLanguages)
        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [pasteAction, selectFileAction],
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

    func resolveEmptyDerivationPath(
        sourceViewModel: InputViewModelProtocol,
        usernameViewModel: InputViewModelProtocol,
        selectedCryptoType: CryptoType,
        selectedSourceType: AccountImportSource
    ) {
        let message = R.string.localizable.importEmptyDerivationMessage(preferredLanguages: localizationManager?.selectedLocale.rLanguages)
        let replaceActionTitle = R.string.localizable.importEmptyDerivationConfirm(preferredLanguages: localizationManager?.selectedLocale.rLanguages)
        let cancelActionTitle = R.string.localizable.importEmptyDerivationCancel(preferredLanguages: localizationManager?.selectedLocale.rLanguages)
        let replaceAction = AlertPresentableAction(title: replaceActionTitle) { [weak self] in
            self?.view?.didValidateEthereumDerivationPath(.valid)
            self?.createAccount(
                sourceViewModel: sourceViewModel,
                username: usernameViewModel.inputHandler.value,
                substrateDerivationPath: (self?.substrateDerivationPathViewModel?.inputHandler.value).nonEmpty(or: ""),
                ethereumDerivationPath: "",
                selectedCryptoType: selectedCryptoType,
                password: self?.passwordViewModel?.inputHandler.value ?? "",
                selectedSourceType: selectedSourceType
            )
        }
        let cancelAction = AlertPresentableAction(title: cancelActionTitle, style: .cancel) { [weak self] in
            self?.view?.didValidateEthereumDerivationPath(.valid)
            self?.createAccount(
                sourceViewModel: sourceViewModel,
                username: usernameViewModel.inputHandler.value,
                substrateDerivationPath: (self?.substrateDerivationPathViewModel?.inputHandler.value).nonEmpty(or: ""),
                ethereumDerivationPath: (self?.ethereumDerivationPathViewModel?.inputHandler.value)
                    .nonEmpty(or: DerivationPathConstants.defaultEthereum),
                selectedCryptoType: selectedCryptoType,
                password: self?.passwordViewModel?.inputHandler.value ?? "",
                selectedSourceType: selectedSourceType
            )
        }
        let alertViewModel = AlertPresentableViewModel(
            title: nil,
            message: message,
            actions: [replaceAction, cancelAction],
            closeAction: nil
        )
        wireframe.present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
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
        if ethereumDerivationPathViewModel?.inputHandler.value == DerivationPathConstants.zerosEthereum {
            resolveEmptyDerivationPath(
                sourceViewModel: sourceViewModel,
                usernameViewModel: usernameViewModel,
                selectedCryptoType: selectedCryptoType,
                selectedSourceType: selectedSourceType
            )
            return
        }

        createAccount(
            sourceViewModel: sourceViewModel,
            username: usernameViewModel.inputHandler.value,
            substrateDerivationPath: (substrateDerivationPathViewModel?.inputHandler.value).nonEmpty(or: ""),
            ethereumDerivationPath: (ethereumDerivationPathViewModel?.inputHandler.value)
                .nonEmpty(or: DerivationPathConstants.defaultEthereum),
            selectedCryptoType: selectedCryptoType,
            password: passwordViewModel?.inputHandler.value ?? "",
            selectedSourceType: selectedSourceType
        )
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
        let preferredData = PreferredData(jsonData: preferredInfo)
        applySourceType(text, preferredData: preferredData)
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

extension AccountImportPresenter: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        guard let jsonData = try? Data(contentsOf: url, options: .dataReadingMapped),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        interactor.deriveMetadataFromKeystore(jsonString)
    }
}
