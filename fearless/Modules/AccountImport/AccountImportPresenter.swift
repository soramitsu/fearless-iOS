import Foundation
import IrohaCrypto
import Rswift
import SoraFoundation
import SSFModels
import SSFUtils

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
    private var cryptoTypeSelectable = false

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var substrateDerivationPathViewModel: InputViewModelProtocol?
    private(set) var ethereumDerivationPathViewModel: InputViewModelProtocol?

    private lazy var jsonDeserializer = JSONSerialization()
    private var isImportInProgress = false
    private var isPersistencePending = false
    private var hasCommittedImport = false
    private var didNavigateAfterImport = false
    private var isImportPresentationSuspended = false
    private var isApplicationActive = true
    private var requiresExplicitImportCompletion = false
    private let nativeTonImport: NativeTonImportCoordinator
    private var inputState: ErrorPresentableInputField.State = .normal {
        didSet {
            view?.didChangeState(inputState)
        }
    }

    init(
        wireframe: AccountImportWireframeProtocol,
        interactor: AccountImportInteractorInputProtocol,
        flow: AccountImportFlow,
        nativeTonImport: NativeTonImportCoordinator = NativeTonImportCoordinator()
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.flow = flow
        self.nativeTonImport = nativeTonImport
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(importApplicationWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(importApplicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

private extension AccountImportPresenter {
    var ownsImportPresentation: Bool {
        guard
            !isImportPresentationSuspended, isApplicationActive, !didNavigateAfterImport,
            UIApplication.shared.applicationState != .background,
            let controller = view?.controller,
            controller.viewIfLoaded?.window != nil,
            !controller.isBeingDismissed, !controller.isMovingFromParent,
            controller.navigationController.map({ $0.topViewController === controller }) ?? true
        else { return false }
        return true
    }

    @objc func importApplicationWillResignActive() {
        isApplicationActive = false
        if isPersistencePending { requiresExplicitImportCompletion = true }
        nativeTonImport.cancel()
    }

    @objc func importApplicationDidBecomeActive() {
        // Becoming active never replays a completion. Continue explicitly finishes
        // an acknowledged import without issuing another key/store transaction.
        isApplicationActive = true
    }

    func persistMetaAccount(request: MetaAccountImportRequest) {
        guard ownsImportPresentation, isImportInProgress, !isPersistencePending, !hasCommittedImport else { return }
        isPersistencePending = true
        updateImportPersistenceView()
        interactor.importMetaAccount(request: request)
    }

    func persistUniqueChain(request: UniqueChainImportRequest) {
        guard ownsImportPresentation, isImportInProgress, !isPersistencePending, !hasCommittedImport else { return }
        isPersistencePending = true
        updateImportPersistenceView()
        interactor.importUniqueChain(request: request)
    }

    func updateImportPersistenceView() {
        (view as? AccountImportPersistenceView)?.bindImportPersistence(
            pending: isPersistencePending, committed: hasCommittedImport
        )
    }

    func finishCommittedImport() {
        guard hasCommittedImport, ownsImportPresentation,
              view?.controller.presentedViewController == nil else { return }
        didNavigateAfterImport = true
        wireframe.proceed(from: view, flow: flow)
    }

    var isDedicatedBitcoinChainFlow: Bool {
        guard case let .chain(model) = flow else {
            return false
        }

        return UniversalWalletRegistry.bitcoinNetwork(for: model.chain.chainId) != nil
    }

    var isDedicatedUniversalChainFlow: Bool {
        guard case let .chain(model) = flow else {
            return false
        }

        // Bitcoin, Solana and Taira come from the wallet's own recovery phrase
        // (`UniversalRootRecoveryOperation`): no raw seed, JSON or derivation options.
        return isDedicatedBitcoinChainFlow ||
            UniversalWalletRegistry.solanaNetwork(for: model.chain.chainId) != nil ||
            UniversalWalletChainAccountSupport.chainId(
                model.chain.chainId,
                matches: UniversalWalletRegistry.taira.chainId
            )
    }

    var dedicatedUniversalCryptoType: CryptoType {
        guard case let .chain(model) = flow,
              UniversalWalletRegistry.solanaNetwork(for: model.chain.chainId) != nil ||
              UniversalWalletChainAccountSupport.chainId(
                  model.chain.chainId,
                  matches: UniversalWalletRegistry.taira.chainId
              ) else {
            return .ecdsa
        }

        return .ed25519
    }

    func applySourceType(
        _ value: String = "",
        preferredData: PreferredData? = nil
    ) {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        switch flow {
        case let .chain(model):
            let chainType: AccountCreateChainType
            if isDedicatedUniversalChainFlow {
                chainType = .universal
            } else {
                chainType = model.chain.isEthereumBased ? .ethereum : .substrate
            }
            view?.setSource(
                type: selectedSourceType,
                chainType: chainType,
                selectable: !isDedicatedUniversalChainFlow
            )
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
        if isDedicatedUniversalChainFlow {
            substrateDerivationPathViewModel = nil
            ethereumDerivationPathViewModel = nil
            view?.show(chainType: .universal)
        } else {
            applyAdvanced(preferredData?.cryptoType)
        }
    }

    func sourcePlaceholder(for source: AccountImportSource) -> String {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        switch source {
        case .mnemonic:
            return R.string.localizable.importMnemonic(preferredLanguages: locale.rLanguages)
        case .legacyTonMnemonic:
            return R.string.localizable.importLegacy_ton_phrase_placeholder(preferredLanguages: locale.rLanguages)
        case .seed:
            return flow.isEthereumFlow ?
                R.string.localizable.accountImportEthereumRawSeedPlaceholder(preferredLanguages: locale.rLanguages) :
                R.string.localizable.accountImportSubstrateRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
        case .keystore:
            return R.string.localizable.accountImportRecoveryJsonPlaceholder(preferredLanguages: locale.rLanguages)
        }
    }

    func applySourceTextViewModel(_ value: String = "") {
        guard let selectedSourceType = selectedSourceType else { return }
        let inputHandler: InputHandling
        switch selectedSourceType {
        case .mnemonic:
            inputHandler = InputHandler(value: value, normalizer: MnemonicTextNormalizer())
        case .legacyTonMnemonic, .seed, .keystore:
            inputHandler = InputHandler(value: value)
        }
        let viewModel = InputViewModel(
            inputHandler: inputHandler, placeholder: sourcePlaceholder(for: selectedSourceType)
        )
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
        case .mnemonic, .legacyTonMnemonic, .seed:
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
        case .legacyTonMnemonic:
            selectedCryptoType = .ed25519
            substrateDerivationPathViewModel = nil
            ethereumDerivationPathViewModel = nil
            view?.show(chainType: .universal)
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

    func applyCryptoTypeViewModel(
        _ preselectedCryptoType: CryptoType? = nil, preservingSelectability: Bool = false
    ) {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let viewModel = TitleWithSubtitleViewModel(
            title: cryptoType.titleForLocale(locale),
            subtitle: cryptoType.subtitleForLocale(locale)
        )

        let selectable: Bool

        if preservingSelectability {
            selectable = cryptoTypeSelectable
        } else if preselectedCryptoType != nil {
            selectable = false
        } else {
            selectable = (metadata?.availableCryptoTypes.count ?? 0) > 1
        }

        cryptoTypeSelectable = selectable
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

    func askWhichSubstrateAccount(
        _ accounts: [SubstratePasswordAccount],
        choose: @escaping (SubstratePasswordRule) -> Void
    ) {
        let languages = selectedLocale.rLanguages
        let title: (SubstratePasswordRule) -> String = { rule in
            switch rule {
            case .nfkd:
                return R.string.localizable.substratePasswordChoiceNfkd(preferredLanguages: languages)
            case .nfc:
                return R.string.localizable.substratePasswordChoiceNfc(preferredLanguages: languages)
            case .asTyped:
                return R.string.localizable.substratePasswordChoiceAsTyped(preferredLanguages: languages)
            }
        }
        let lines = accounts.map { "\(title($0.rule)):\n\($0.address)" }
        let message = ([R.string.localizable.substratePasswordChoiceMessage(preferredLanguages: languages)] + lines)
            .joined(separator: "\n\n")
        let actions = accounts.enumerated().map { index, account in
            SheetAlertPresentableAction(
                title: title(account.rule),
                style: index == 0 ? .pinkBackgroundWhiteText : .grayBackgroundWhiteText,
                handlerAfterDismissal: true,
                handler: { choose(account.rule) }
            )
        }
        let alertViewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.substratePasswordChoiceTitle(preferredLanguages: languages),
            message: message,
            actions: actions,
            closeAction: nil,
            icon: nil,
            scrollableContent: true
        )
        wireframe.present(viewModel: alertViewModel, from: view)
    }

    /// The accounts a network's own import can open when the rules read the path's password
    /// differently, in that network's address format; nil when there is nothing to choose. The
    /// universal networks derive from the wallet's root instead and never ask.
    func substratePasswordAccounts(
        for data: UniqueChainImportRequestData,
        mnemonic: IRMnemonicProtocol
    ) -> [SubstratePasswordAccount]? {
        guard !data.chain.isEthereumBased,
              !UniversalWalletChainAccountSupport.isUniversalWalletChain(data.chain.chainId),
              SubstratePasswordRule.distinctRules(forSubstrateDerivationPath: data.derivationPath).count > 1,
              let accounts = try? SubstratePasswordRule.accounts(
                  mnemonic: mnemonic,
                  derivationPath: data.derivationPath,
                  cryptoType: data.selectedCryptoType
              ),
              accounts.count > 1
        else {
            return nil
        }
        return accounts.map { account in
            let address = (try? account.publicKey.publicKeyToAccountId().toAddress(using: data.chain.chainFormat))
            return SubstratePasswordAccount(
                rule: account.rule,
                publicKey: account.publicKey,
                address: address ?? account.address
            )
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
        guard ownsImportPresentation, !isImportInProgress, !hasCommittedImport else {
            return
        }

        requiresExplicitImportCompletion = false
        isImportInProgress = true

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

    func importMetaAccount(
        data: AccountImportRequestData,
        step: AccountCreationStep,
        substratePasswordRule: SubstratePasswordRule? = nil
    ) {
        switch (data.selectedSourceType, step) {
        case (.mnemonic, _), (.legacyTonMnemonic, _):
            let mnemonicString = data.source
            let parsed: IRMnemonicProtocol? = data.selectedSourceType == .legacyTonMnemonic
                ? (try? LegacyTonMnemonic.validatedForImport(mnemonicString))
                : interactor.createMnemonicFromString(mnemonicString)
            guard let mnemonic = parsed else {
                didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
                return
            }
            // An earlier browser extension made a different account from the path's password
            // (SubstratePasswordRule): the user picks before the wallet is saved. Accounts are
            // derived only when the rules read the password differently (never for ASCII).
            if data.selectedSourceType == .mnemonic, substratePasswordRule == nil,
               SubstratePasswordRule.distinctRules(forSubstrateDerivationPath: data.substrateDerivationPath).count > 1,
               let accounts = try? SubstratePasswordRule.accounts(
                   mnemonic: mnemonic,
                   derivationPath: data.substrateDerivationPath,
                   cryptoType: data.selectedCryptoType
               ),
               accounts.count > 1 {
                isImportInProgress = false
                askWhichSubstrateAccount(accounts) { [weak self] rule in
                    guard let self, self.ownsImportPresentation,
                          !self.isImportInProgress, !self.hasCommittedImport else { return }
                    self.requiresExplicitImportCompletion = false
                    self.isImportInProgress = true
                    self.importMetaAccount(data: data, step: step, substratePasswordRule: rule)
                }
                return
            }
            let sourceData = MetaAccountImportRequestSource.MnemonicImportRequestData(
                mnemonic: mnemonic,
                substrateDerivationPath: data.substrateDerivationPath,
                ethereumDerivationPath: data.ethereumDerivationPath,
                substratePasswordRule: substratePasswordRule ?? .nfkd
            )
            let source = MetaAccountImportRequestSource.mnemonic(data: sourceData)
            let request = MetaAccountImportRequest(
                source: source,
                username: data.username,
                cryptoType: data.selectedCryptoType,
                defaultChainId: nil
            )
            persistMetaAccount(request: request)
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
                self?.persistMetaAccount(request: request)
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
                self?.persistMetaAccount(request: request)
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
            persistMetaAccount(request: request)
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
            persistMetaAccount(request: request)
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

    func importUniqueChain(data: UniqueChainImportRequestData, substratePasswordRule: SubstratePasswordRule? = nil) {
        var source: UniqueChainImportRequestSource
        switch data.selectedSourceType {
        case .legacyTonMnemonic:
            didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
            return
        case .mnemonic:
            guard let mnemonic = interactor.createMnemonicFromString(data.source) else {
                didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
                return
            }
            // One network's account can be one an earlier browser extension made, as in a
            // whole-wallet import: the user picks before it is saved.
            if substratePasswordRule == nil, let accounts = substratePasswordAccounts(for: data, mnemonic: mnemonic) {
                isImportInProgress = false
                askWhichSubstrateAccount(accounts) { [weak self] rule in
                    guard let self, self.ownsImportPresentation,
                          !self.isImportInProgress, !self.hasCommittedImport else { return }
                    self.requiresExplicitImportCompletion = false
                    self.isImportInProgress = true
                    self.importUniqueChain(data: data, substratePasswordRule: rule)
                }
                return
            }
            let sourceData = UniqueChainImportRequestSource.MnemonicImportRequestData(
                mnemonic: mnemonic,
                derivationPath: data.derivationPath,
                substratePasswordRule: substratePasswordRule ?? .nfkd
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
        persistUniqueChain(request: request)
    }

    func validateSource(with value: String) -> Error? {
        guard let selectedSourceType = selectedSourceType else {
            return nil
        }

        switch selectedSourceType {
        case .legacyTonMnemonic:
            // Native TON validation and candidate derivation run off the main thread.
            return nil
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
                text: isDedicatedUniversalChainFlow
                    ? R.string.localizable.universalImportEntireWallet(
                        preferredLanguages: localizationManager?.selectedLocale.rLanguages
                    )
                    : model.chain.name,
                icon: isDedicatedUniversalChainFlow
                    ? nil
                    : model.chain.icon.map { RemoteImageViewModel(url: $0) }
            )
            view?.setUniqueChain(viewModel: viewModel)
        }
    }

    func selectSourceType() {
        guard ownsImportPresentation, !isImportInProgress, !hasCommittedImport else { return }
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
        guard ownsImportPresentation, !isImportInProgress, !hasCommittedImport else { return }
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
        guard ownsImportPresentation, !isImportInProgress, !hasCommittedImport else { return }
        let locale = localizationManager?.selectedLocale

        let pasteTitle = R.string.localizable
            .accountImportRecoveryJsonPlaceholder(preferredLanguages: locale?.rLanguages)
        let pasteAction = SheetAlertPresentableAction(title: pasteTitle) { [weak self] in
            if let json = UIPasteboard.general.string {
                self?.interactor.deriveMetadataFromKeystore(json)
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
        guard ownsImportPresentation else { return }
        if hasCommittedImport {
            finishCommittedImport()
            return
        }
        guard
            !isImportInProgress, !nativeTonImport.isPending,
            let selectedSourceType = selectedSourceType,
            let selectedCryptoType = selectedCryptoType,
            let usernameViewModel = usernameViewModel,
            let sourceViewModel = sourceViewModel
        else {
            return
        }
        let input = selectedSourceType == .legacyTonMnemonic
            ? sourceViewModel.inputHandler.value
            : sourceViewModel.inputHandler.normalizedValue.trimmingCharacters(in: .whitespacesAndNewlines)

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
        if selectedSourceType == .legacyTonMnemonic {
            guard let owner = view?.controller else { return }
            nativeTonImport.start(
                phrase: input, locale: selectedLocale, from: owner,
                isCurrent: { [weak self] in
                    self?.selectedSourceType == .legacyTonMnemonic &&
                        self?.sourceViewModel?.inputHandler.value == data.source &&
                        self?.usernameViewModel?.inputHandler.value == data.username
                }, completion: { [weak self] result in
                    guard let self, self.ownsImportPresentation,
                          !self.isImportInProgress, !self.hasCommittedImport else { return }
                    switch result {
                    case let .failure(error):
                        self.didReceiveAccountImport(error: error)
                    case let .success(mnemonic):
                        self.requiresExplicitImportCompletion = false
                        self.isImportInProgress = true
                        let source = MetaAccountImportRequestSource.MnemonicImportRequestData(
                            mnemonic: mnemonic, substrateDerivationPath: "", ethereumDerivationPath: ""
                        )
                        self.persistMetaAccount(request: MetaAccountImportRequest(
                            source: .mnemonic(data: source), username: data.username,
                            cryptoType: data.selectedCryptoType, defaultChainId: nil
                        ))
                    }
                }
            )
        } else {
            createAccount(data: data)
        }
    }

    func validateInput(value: String) {
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
        let effectiveMetadata: MetaAccountImportMetadata
        if isDedicatedUniversalChainFlow {
            effectiveMetadata = MetaAccountImportMetadata(
                availableSources: [.mnemonic],
                defaultSource: .mnemonic,
                availableCryptoTypes: [dedicatedUniversalCryptoType],
                defaultCryptoType: dedicatedUniversalCryptoType
            )
        } else if case .wallet(step: .substrate) = flow {
            effectiveMetadata = metadata
        } else {
            effectiveMetadata = MetaAccountImportMetadata(
                availableSources: metadata.availableSources.filter { $0 != .legacyTonMnemonic },
                defaultSource: metadata.defaultSource == .legacyTonMnemonic ? .mnemonic : metadata.defaultSource,
                availableCryptoTypes: metadata.availableCryptoTypes,
                defaultCryptoType: metadata.defaultCryptoType
            )
        }
        self.metadata = effectiveMetadata

        selectedSourceType = effectiveMetadata.defaultSource
        selectedCryptoType = effectiveMetadata.defaultCryptoType

        applySourceType()
    }

    func didCompleteAccountImport() {
        didAcknowledgeAccountImport(selectionIsCurrent: true)
    }

    func didReceiveAccountImport(error: Error) {
        guard !hasCommittedImport, !didNavigateAfterImport else { return }
        isImportInProgress = false
        isPersistencePending = false
        updateImportPersistenceView()
        guard !requiresExplicitImportCompletion, ownsImportPresentation,
              view?.controller.presentedViewController == nil else { return }
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
        guard let view = view, view.isSetup else { return }
        // A locale change only changes captions. Keep every draft handler, its
        // normalizer, metadata restrictions and the expanded/validation state.
        if let current = sourceViewModel, let source = selectedSourceType {
            let localized = InputViewModel(
                inputHandler: current.inputHandler, title: current.title,
                placeholder: sourcePlaceholder(for: source), autocapitalization: current.autocapitalization
            )
            sourceViewModel = localized
            view.setSource(viewModel: localized)
        }
        applyCryptoTypeViewModel(preservingSelectability: true)
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

protocol AccountImportPresentationOwning: NativeTonImportLifecycleOwning {
    func suspendPendingImportPresentation()
    func resumeImportPresentation()
}

protocol AccountImportAcknowledgementReceiving: AnyObject {
    func didAcknowledgeAccountImport(selectionIsCurrent: Bool)
}

extension AccountImportInteractorOutputProtocol {
    func completeAccountImport(selectionIsCurrent: Bool) {
        if let owner = self as? AccountImportAcknowledgementReceiving {
            owner.didAcknowledgeAccountImport(selectionIsCurrent: selectionIsCurrent)
        } else {
            didCompleteAccountImport()
        }
    }
}

extension AccountImportPresenter: AccountImportAcknowledgementReceiving {
    func didAcknowledgeAccountImport(selectionIsCurrent: Bool) {
        guard isPersistencePending, !hasCommittedImport else { return }
        isImportInProgress = false
        isPersistencePending = false
        hasCommittedImport = true
        requiresExplicitImportCompletion = requiresExplicitImportCompletion || !selectionIsCurrent
        updateImportPersistenceView()
        if !requiresExplicitImportCompletion { finishCommittedImport() }
    }
}

/// Leaving revokes presentation, not persistence. Acknowledged keys remain committed.
extension AccountImportPresenter: AccountImportPresentationOwning {
    func suspendPendingImportPresentation() {
        // A chooser may cover the form before any persistence is issued. Only an
        // outstanding write needs a terminal Continue after a covering transition.
        guard isPersistencePending else { return }
        isImportPresentationSuspended = true
        requiresExplicitImportCompletion = true
    }

    func cancelPendingNativeTonImport() {
        isImportPresentationSuspended = true
        if isPersistencePending { requiresExplicitImportCompletion = true }
        nativeTonImport.cancel()
    }

    func resumeImportPresentation() {
        // Also restores a cancelled interactive Back gesture. Late acknowledgements
        // still require an explicit Continue after ownership has been interrupted.
        isImportPresentationSuspended = false
    }
}
