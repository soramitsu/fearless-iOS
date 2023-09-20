import Foundation
import SoraFoundation
import Rswift
import SSFUtils
import SSFModels

// swiftlint:disable function_body_length file_length
enum AccountImportContext: String {
    case sourceType
    case cryptoType
}

struct UniqueChainModel {
    let meta: MetaAccountModel
    let chain: ChainModel
}

enum AccountImportFlow {
    case chain(model: UniqueChainModel)
    case wallet(step: AccountCreationStep)

    var isEthereumFlow: Bool {
        switch self {
        case let .chain(model):
            return model.chain.isEthereumBased
        case let .wallet(step):
            switch step {
            case .substrate:
                return false
            case .ethereum:
                return true
            }
        }
    }

    func provideSubstrateStepDataIfNeed() -> AccountCreationStep.SubstrateStepData? {
        switch self {
        case let .wallet(step):
            switch step {
            case let .ethereum(data):
                return data
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

struct AccountImportRequestData {
    let selectedSourceType: AccountImportSource
    let source: String
    let username: String
    let ethereumDerivationPath: String
    let substrateDerivationPath: String
    let selectedCryptoType: CryptoType
    let password: String
}

struct UniqueChainImportRequestData {
    let selectedSourceType: AccountImportSource
    let source: String
    let username: String
    let derivationPath: String
    let selectedCryptoType: CryptoType
    let password: String
    let meta: MetaAccountModel
    let chain: ChainModel
}

struct PreferredData {
    let sourceType: AccountImportSource?
    let source: String?
    let username: String?
    let password: String?
    let cryptoType: CryptoType?
    let derivationPath: String?

    init(stepData: AccountCreationStep.SubstrateStepData) {
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

final class AccountImportPresenter: NSObject {
    static let onFlyValidationEnabled: Bool = false
    static let maxMnemonicLength: Int = 250
    static let maxMnemonicSize: Int = 24
    static let maxRawSeedLength: Int = 66
    static let maxKeystoreLength: Int = 4000
    static let ethereumDerivationPathLength: Int = 15

    weak var view: AccountImportViewProtocol?
    var wireframe: AccountImportWireframeProtocol
    var interactor: AccountImportInteractorInputProtocol

    let flow: AccountImportFlow
    private(set) var metadata: MetaAccountImportMetadata?

    private(set) var selectedSourceType: AccountImportSource?
    private(set) var selectedCryptoType: CryptoType?

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var substrateDerivationPathViewModel: InputViewModelProtocol?
    private(set) var ethereumDerivationPathViewModel: InputViewModelProtocol?

    private lazy var jsonDeserializer = JSONSerialization()
    private var input: String?
    private var inputState: ErrorPresentableInputField.State = .normal {
        didSet {
            view?.didChangeState(inputState)
        }
    }

    init(
        wireframe: AccountImportWireframeProtocol,
        interactor: AccountImportInteractorInputProtocol,
        flow: AccountImportFlow
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.flow = flow
    }
}

private extension AccountImportPresenter {
    func applySourceType(
        _ value: String = "",
        preferredData: PreferredData? = nil
    ) {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        switch flow {
        case let .chain(model):
            let chainType: AccountCreateChainType = model.chain.isEthereumBased ? .ethereum : .substrate
            view?.setSource(type: selectedSourceType, chainType: chainType, selectable: true)
        case let .wallet(step):
            switch step {
            case .substrate:
                view?.setSource(type: selectedSourceType, chainType: .substrate, selectable: true)
            case let .ethereum(data):
                selectedCryptoType = data.cryptoType
                view?.setSource(type: selectedSourceType, chainType: .ethereum, selectable: false)
            }
        }

        applySourceTextViewModel(value)

        let username: String
        switch flow {
        case let .chain(model):
            username = model.meta.name
        case let .wallet(step):
            switch step {
            case .substrate:
                username = preferredData?.username ?? ""
            case let .ethereum(data):
                username = data.username
            }
        }
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
                normalizer: normalizer
            )
            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)
        case .seed:
            var placeholder: String
            if flow.isEthereumFlow {
                placeholder = R.string.localizable
                    .accountImportEthereumRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
            } else {
                placeholder = R.string.localizable
                    .accountImportSubstrateRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
            }
            let inputHandler = InputHandler(
                value: value
            )
            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)
        case .keystore:
            let placeholder = R.string.localizable
                .accountImportRecoveryJsonPlaceholder(preferredLanguages: locale.rLanguages)
            let inputHandler = InputHandler(
                value: value
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

        var visible: Bool
        switch flow {
        case .wallet:
            visible = true
        case .chain:
            visible = false
        }

        view?.setName(viewModel: viewModel, visible: visible)
    }

    func applyPasswordViewModel() {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        switch selectedSourceType {
        case .mnemonic, .seed:
            passwordViewModel = nil
        case .keystore:
            let viewModel = InputViewModel(inputHandler: InputHandler(required: true))
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

            switch flow {
            case .wallet:
                applySubstrateDerivationPathViewModel()
                applyEthereumDerivationPathViewModel()
                view?.show(chainType: .both)
            case let .chain(model):
                if model.chain.isEthereumBased {
                    applyEthereumDerivationPathViewModel()
                    view?.show(chainType: .ethereum)
                } else {
                    applySubstrateDerivationPathViewModel()
                    view?.show(chainType: .substrate)
                }
            }
        case .seed:
            applyCryptoTypeViewModel(cryptoType)
            if flow.isEthereumFlow {
                applyEthereumDerivationPathViewModel()
                view?.show(chainType: .ethereum)
            } else {
                applySubstrateDerivationPathViewModel()
                view?.show(chainType: .substrate)
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
        let processor = NumbersAndSlashesProcessor()

        let viewModel = createViewModel(
            for: .ecdsa,
            sourceType: sourceType,
            isEthereum: true,
            processor: processor
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
            predicate = NSPredicate.deriviationPathHardSoft
            placeholder = DerivationPathConstants.hardSoftPlaceholder
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
            error = .invalidDerivationHardSoftNumeric
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

    func validateMnemonic(value: String) -> Error? {
        if value.rangeOfCharacter(from: CharacterSet.englishMnemonic.inverted) != nil {
            return AccountCreateError.invalidMnemonicFormat
        }

        let mnemonicSize = value.components(separatedBy: CharacterSet.whitespaces).count
        return mnemonicSize > AccountImportPresenter.maxMnemonicSize ?
            AccountCreateError.invalidMnemonicSize : nil
    }

    func validateSeed(value: String) -> Error? {
        guard !value.isEmpty else {
            return nil
        }

        let validFormat = NSPredicate.seed.evaluate(with: value)
        if !validFormat {
            return AccountCreateError.invalidSeed
        }

        if value.count > Self.maxRawSeedLength {
            return AccountCreateError.invalidSeed
        }

        return nil
    }

    func validateKeystore(value: String) -> Error? {
        guard value.count < Self.maxKeystoreLength, value.isNotEmpty, let data = value.data(using: .utf8) else {
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
        let showAction = SheetAlertPresentableAction(
            title: R.string.localizable.commonYes(preferredLanguages: selectedLocale.rLanguages),
            style: .pinkBackgroundWhiteText,
            handler: showHandler
        )
        let closeAction = SheetAlertPresentableAction(
            title: R.string.localizable.commonNo(preferredLanguages: selectedLocale.rLanguages),
            handler: closeHandler
        )
        let alertViewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.alertAddEthereumTitle(preferredLanguages: selectedLocale.rLanguages),
            message: R.string.localizable.alertAddEthereumMessage(preferredLanguages: selectedLocale.rLanguages),
            actions: [showAction, closeAction],
            closeAction: nil,
            icon: R.image.iconWarningBig()
        )
        wireframe.present(viewModel: alertViewModel, from: view)
    }

    func createAccount(data: AccountImportRequestData) {
        switch flow {
        case let .chain(model):
            let derivationPath = model.chain.isEthereumBased
                ? data.ethereumDerivationPath
                : data.substrateDerivationPath
            let data = UniqueChainImportRequestData(
                selectedSourceType: data.selectedSourceType,
                source: data.source,
                username: data.username,
                derivationPath: derivationPath,
                selectedCryptoType: data.selectedCryptoType,
                password: data.password,
                meta: model.meta,
                chain: model.chain
            )
            importUniqueChain(data: data)
        case let .wallet(step):
            importMetaAccount(data: data, step: step)
        }
    }

    func importMetaAccount(data: AccountImportRequestData, step: AccountCreationStep) {
        switch (data.selectedSourceType, step) {
        case (.mnemonic, _):
            let mnemonicString = data.source
            guard let mnemonic = interactor.createMnemonicFromString(mnemonicString) else {
                didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
                return
            }
            let sourceData = MetaAccountImportRequestSource.MnemonicImportRequestData(
                mnemonic: mnemonic,
                substrateDerivationPath: data.substrateDerivationPath,
                ethereumDerivationPath: data.ethereumDerivationPath
            )
            let source = MetaAccountImportRequestSource.mnemonic(data: sourceData)
            let request = MetaAccountImportRequest(
                source: source,
                username: data.username,
                cryptoType: data.selectedCryptoType,
                defaultChainId: nil
            )
            interactor.importMetaAccount(request: request)
        case (.seed, .substrate):
            askIfNeedAddEthereum { [weak self] in
                self?.showSecondStep(data: data)
            } closeHandler: { [weak self] in
                let sourceData = MetaAccountImportRequestSource.SeedImportRequestData(
                    substrateSeed: data.source,
                    ethereumSeed: nil,
                    substrateDerivationPath: data.substrateDerivationPath,
                    ethereumDerivationPath: nil
                )
                let source = MetaAccountImportRequestSource.seed(data: sourceData)
                let request = MetaAccountImportRequest(
                    source: source,
                    username: data.username,
                    cryptoType: data.selectedCryptoType,
                    defaultChainId: nil
                )
                self?.interactor.importMetaAccount(request: request)
            }
        case (.keystore, .substrate):
            askIfNeedAddEthereum { [weak self] in
                self?.showSecondStep(data: data)
            } closeHandler: { [weak self] in
                let sourceData = MetaAccountImportRequestSource.KeystoreImportRequestData(
                    substrateKeystore: data.source,
                    ethereumKeystore: nil,
                    substratePassword: data.password,
                    ethereumPassword: nil
                )
                let source = MetaAccountImportRequestSource.keystore(data: sourceData)
                let request = MetaAccountImportRequest(
                    source: source,
                    username: data.username,
                    cryptoType: data.selectedCryptoType,
                    defaultChainId: nil
                )
                self?.interactor.importMetaAccount(request: request)
            }
        case let (.seed, .ethereum(previousStepData)):
            let sourceData = MetaAccountImportRequestSource.SeedImportRequestData(
                substrateSeed: previousStepData.source,
                ethereumSeed: data.source,
                substrateDerivationPath: previousStepData.derivationPath,
                ethereumDerivationPath: data.ethereumDerivationPath
            )
            let source = MetaAccountImportRequestSource.seed(data: sourceData)
            let request = MetaAccountImportRequest(
                source: source,
                username: previousStepData.username,
                cryptoType: previousStepData.cryptoType,
                defaultChainId: nil
            )
            interactor.importMetaAccount(request: request)
        case let (.keystore, .ethereum(previousStepData)):
            let sourceData = MetaAccountImportRequestSource.KeystoreImportRequestData(
                substrateKeystore: previousStepData.source,
                ethereumKeystore: data.source,
                substratePassword: previousStepData.password,
                ethereumPassword: data.password
            )
            let source = MetaAccountImportRequestSource.keystore(data: sourceData)
            let request = MetaAccountImportRequest(
                source: source,
                username: previousStepData.username,
                cryptoType: previousStepData.cryptoType,
                defaultChainId: nil
            )
            interactor.importMetaAccount(request: request)
        }
    }

    func showSecondStep(data: AccountImportRequestData) {
        let data = AccountCreationStep.SubstrateStepData(
            sourceType: data.selectedSourceType,
            source: data.source,
            username: data.username,
            password: data.password,
            cryptoType: data.selectedCryptoType,
            derivationPath: data.substrateDerivationPath
        )
        wireframe.showEthereumStep(from: view, with: data)
    }

    func importUniqueChain(data: UniqueChainImportRequestData) {
        var source: UniqueChainImportRequestSource
        switch data.selectedSourceType {
        case .mnemonic:
            guard let mnemonic = interactor.createMnemonicFromString(data.source) else {
                didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
                return
            }
            let sourceData = UniqueChainImportRequestSource.MnemonicImportRequestData(
                mnemonic: mnemonic,
                derivationPath: data.derivationPath
            )
            source = UniqueChainImportRequestSource.mnemonic(data: sourceData)
        case .seed:
            let sourceData = UniqueChainImportRequestSource.SeedImportRequestData(
                seed: data.source,
                derivationPath: data.derivationPath
            )
            source = UniqueChainImportRequestSource.seed(data: sourceData)
        case .keystore:
            let sourceData = UniqueChainImportRequestSource.KeystoreImportRequestData(
                keystore: data.source,
                password: data.password
            )
            source = UniqueChainImportRequestSource.keystore(data: sourceData)
        }
        let request = UniqueChainImportRequest(
            source: source,
            username: data.username,
            cryptoType: data.chain.isEthereumBased ? .ecdsa : data.selectedCryptoType,
            meta: data.meta,
            chain: data.chain
        )
        interactor.importUniqueChain(request: request)
    }

    func validateSource(with value: String) -> Error? {
        guard let selectedSourceType = selectedSourceType else {
            return nil
        }

        switch selectedSourceType {
        case .mnemonic:
            return validateMnemonic(value: value)
        case .seed:
            return validateSeed(value: value)
        case .keystore:
            return validateKeystore(value: value)
        }
    }
}

extension AccountImportPresenter: AccountImportPresenterProtocol {
    func setup() {
        interactor.setup()
        if let data = flow.provideSubstrateStepDataIfNeed() {
            selectedSourceType = data.sourceType
            selectedCryptoType = data.cryptoType
            applySourceType(preferredData: PreferredData(stepData: data))
            applyCryptoTypeViewModel(data.cryptoType)
        }
        if case let .chain(model) = flow {
            let viewModel = UniqueChainViewModel(
                text: model.chain.name,
                icon: model.chain.icon.map { RemoteImageViewModel(url: $0) }
            )
            view?.setUniqueChain(viewModel: viewModel)
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
        let pasteAction = SheetAlertPresentableAction(title: pasteTitle) { [weak self] in
            if let json = UIPasteboard.general.string {
                self?.interactor.deriveMetadataFromKeystore(json)
                self?.input = json
            }
        }
        let selectFileTitle = R.string.localizable
            .accountImportRecoverySelectFile(preferredLanguages: locale?.rLanguages)
        let selectFileAction = SheetAlertPresentableAction(title: selectFileTitle) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.wireframe.presentSelectFilePicker(
                from: strongSelf.view,
                documentTypes: [.json],
                delegate: strongSelf
            )
        }

        let title = R.string.localizable.importRecoveryJson(preferredLanguages: locale?.rLanguages)
        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [pasteAction, selectFileAction],
            closeAction: closeTitle,
            icon: R.image.iconWarningBig()
        )

        wireframe.present(viewModel: viewModel, from: view)
    }

    func validateSubstrateDerivationPath() {
        guard let viewModel = substrateDerivationPathViewModel,
              let cryptoType = selectedCryptoType,
              let sourceType = selectedSourceType
        else {
            return
        }

        if viewModel.inputHandler.completed {
            if viewModel.inputHandler.value.isEmpty {
                view?.didValidateSubstrateDerivationPath(.none)
            } else {
                view?.didValidateSubstrateDerivationPath(.valid)
            }
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

        if viewModel.inputHandler.value.components(separatedBy: "/").map({ component in
            component.replacingOccurrences(of: "/", with: "", options: NSString.CompareOptions.literal, range: nil)
        }).filter({ component in
            if component.isEmpty {
                return false
            }
            if let _ = UInt32(component) {
                return false
            } else {
                return true
            }
        }).isEmpty, viewModel.inputHandler.completed {
            if viewModel.inputHandler.value.isEmpty {
                view?.didValidateEthereumDerivationPath(.none)
            } else {
                view?.didValidateEthereumDerivationPath(.valid)
            }
        } else {
            view?.didValidateEthereumDerivationPath(.invalid)
            presentDerivationPathError(
                sourceType: sourceType,
                cryptoType: .ecdsa,
                isEthereum: true
            )
        }
    }

    func resolveEmptyDerivationPath(data: AccountImportRequestData) {
        let message = R.string.localizable
            .importEmptyDerivationMessage(
                preferredLanguages: localizationManager?.selectedLocale.rLanguages
            )
        let replaceActionTitle = R.string.localizable
            .importEmptyDerivationConfirm(
                preferredLanguages: localizationManager?.selectedLocale.rLanguages
            )
        let cancelActionTitle = R.string.localizable
            .importEmptyDerivationCancel(
                preferredLanguages: localizationManager?.selectedLocale.rLanguages
            )
        let replaceAction = SheetAlertPresentableAction(title: replaceActionTitle) { [weak self] in
            self?.view?.didValidateEthereumDerivationPath(.valid)
            let updatedData = AccountImportRequestData(
                selectedSourceType: data.selectedSourceType,
                source: data.source,
                username: data.username,
                ethereumDerivationPath: data.ethereumDerivationPath,
                substrateDerivationPath: data.substrateDerivationPath,
                selectedCryptoType: data.selectedCryptoType,
                password: data.password
            )
            self?.createAccount(data: updatedData)
        }
        let cancelAction = SheetAlertPresentableAction(
            title: cancelActionTitle,
            button: UIFactory.default.createAccessoryButton()
        ) { [weak self] in
            self?.view?.didValidateEthereumDerivationPath(.valid)
            self?.createAccount(data: data)
        }
        let alertViewModel = SheetAlertPresentableViewModel(
            title: "",
            message: message,
            actions: [replaceAction, cancelAction],
            closeAction: nil,
            icon: R.image.iconWarningBig()
        )
        wireframe.present(
            viewModel: alertViewModel,
            from: view
        )
    }

    func proceed() {
        guard
            let selectedSourceType = selectedSourceType,
            let selectedCryptoType = selectedCryptoType,
            let usernameViewModel = usernameViewModel,
            let input = input
        else {
            return
        }

        if let error = validateSource(with: input) {
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
        let data = AccountImportRequestData(
            selectedSourceType: selectedSourceType,
            source: input,
            username: usernameViewModel.inputHandler.value,
            ethereumDerivationPath: (ethereumDerivationPathViewModel?.inputHandler.value)
                .nonEmpty(or: DerivationPathConstants.defaultEthereum),
            substrateDerivationPath: (substrateDerivationPathViewModel?.inputHandler.value).nonEmpty(or: ""),
            selectedCryptoType: selectedCryptoType,
            password: passwordViewModel?.inputHandler.value ?? ""
        )
        if ethereumDerivationPathViewModel?.inputHandler.value == DerivationPathConstants.zerosEthereum {
            resolveEmptyDerivationPath(data: data)
            return
        }
        createAccount(data: data)
    }

    func validateInput(value: String) {
        input = value

        guard AccountImportPresenter.onFlyValidationEnabled else {
            inputState = .normal
            return
        }

        if let error = validateSource(with: value) as? AccountCreateError {
            let message = [error.toErrorContent(for: selectedLocale).title, error.toErrorContent(for: selectedLocale).message].joined(separator: "\n")
            inputState = .error(text: message)
        } else {
            inputState = .normal
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
        wireframe.proceed(from: view, flow: flow)
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
        guard validateJsonForStep(preferredInfo: preferredInfo) else {
            let viewModel = SheetAlertPresentableViewModel(
                title: R.string.localizable.importJsonInvalidFormatTitle(preferredLanguages: selectedLocale.rLanguages),
                message: R.string.localizable.importJsonInvalidImportTypeMessage(preferredLanguages: selectedLocale.rLanguages),
                actions: [],
                closeAction: nil,
                icon: R.image.iconWarningBig()
            )
            wireframe.present(viewModel: viewModel, from: view)
            return
        }
        input = text
        selectedSourceType = .keystore
        let preferredData = PreferredData(jsonData: preferredInfo)
        applySourceType(text, preferredData: preferredData)
    }

    func validateJsonForStep(preferredInfo: MetaAccountImportPreferredInfo?) -> Bool {
        if case let .wallet(step) = flow, case .substrate = step, let info = preferredInfo {
            return info.isEthereum != true
        }
        return true
    }

    func didFailToDeriveMetadataFromKeystore() {
        let error = AccountCreateError.invalidKeystore
        _ = wireframe.present(
            error: error,
            from: view,
            locale: localizationManager?.selectedLocale
        )
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
            showInvalidJsonAlert()
            return
        }
        interactor.deriveMetadataFromKeystore(jsonString)
    }

    private func showInvalidJsonAlert() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let title = R.string.localizable
            .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable
            .accountImportInvalidKeystore(preferredLanguages: locale.rLanguages)

        let action = SheetAlertPresentableAction(
            title: R.string.localizable.commonOk(preferredLanguages: locale.rLanguages)
        )
        let alertViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [action],
            closeAction: nil,
            icon: R.image.iconWarningBig()
        )
        wireframe.present(
            viewModel: alertViewModel,
            from: view
        )
    }
}
