import Foundation
import Observation
import WalletCore

/// First launch and "Add Wallet": choosing a path, setting the app password,
/// offering Touch ID, then creating or importing a wallet.
@MainActor
@Observable
final class OnboardingModel: Identifiable {
    enum Mode: Equatable {
        /// No app password yet: welcome, password, then a wallet.
        case firstRun
        /// The vault is set up but holds no wallet.
        case firstWallet
        /// Adding another wallet from the main window.
        case addWallet
    }

    enum Path: String, CaseIterable, Identifiable {
        case create
        case importPhrase
        case importSeed
        case importJSON
        case watchOnly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .create: return "Create a New Wallet"
            case .importPhrase: return "Recovery Phrase"
            case .importSeed: return "Raw Seed"
            case .importJSON: return "JSON Backup File"
            case .watchOnly: return "Watch-Only Address"
            }
        }

        var detail: String {
            switch self {
            case .create: return "Get a new recovery phrase for Polkadot and Ethereum accounts."
            case .importPhrase: return "12 to 24 words from Fearless or another wallet."
            case .importSeed: return "A 32-byte seed or private key as hex."
            case .importJSON: return "A keystore file exported from Polkadot.js or Fearless."
            case .watchOnly: return "Follow balances of an address without its keys."
            }
        }

        var symbol: String {
            switch self {
            case .create: return "plus.circle.fill"
            case .importPhrase: return "text.word.spacing"
            case .importSeed: return "number"
            case .importJSON: return "doc.badge.arrow.up"
            case .watchOnly: return "eye"
            }
        }

        var firstStep: Step {
            switch self {
            case .create: return .phraseReveal
            case .importPhrase: return .importPhrase
            case .importSeed: return .importSeed
            case .importJSON: return .importJSON
            case .watchOnly: return .watchOnly
            }
        }
    }

    enum Step: Hashable {
        case welcome
        case password
        case biometrics
        case phraseReveal
        case phraseVerify
        case importPhrase
        case importSeed
        case importJSON
        case watchOnly
        case confirm

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .password: return "App Password"
            case .biometrics: return "Touch ID"
            case .phraseReveal: return "Recovery Phrase"
            case .phraseVerify: return "Check Your Backup"
            case .importPhrase: return "Recovery Phrase"
            case .importSeed: return "Raw Seed"
            case .importJSON: return "JSON Backup"
            case .watchOnly: return "Watch-Only"
            case .confirm: return "Your Wallet"
            }
        }
    }

    let id = UUID()
    let mode: Mode
    @ObservationIgnored private let services: WalletServices
    @ObservationIgnored private let existingWalletCount: Int
    @ObservationIgnored private let onFinished: (Wallet) -> Void

    private(set) var step: Step = .welcome
    private(set) var history: [Step] = []
    private(set) var path: Path?
    private(set) var isWorking = false
    var errorMessage: String?

    // App password
    var password = ""
    var passwordConfirmation = ""
    private(set) var vaultInitialized: Bool
    private(set) var biometrics: BiometricsAvailability = .unavailable(reason: "")

    // Create
    var phraseLength: MnemonicLength = .words12
    private(set) var phrase: [String] = []
    var isPhraseRevealed = false
    private(set) var verification: PhraseVerification?
    private(set) var backupVerified = false

    // Import
    let phraseEntry: PhraseEntryModel
    var seedHex = ""
    var seedEcosystem: Ecosystem = .substrate
    private(set) var jsonData: Data?
    private(set) var jsonFileName: String?
    var jsonPassword = ""
    var watchSubstrateAddress = ""
    var watchEVMAddress = ""
    var derivation = DerivationOptions.standard

    // Confirm
    var walletName: String
    private(set) var addressPreview: WalletAddressPreview?
    @ObservationIgnored private var pendingSource: WalletImportSource?
    /// Bumped by every preview request and by Continue, so a preview that
    /// finishes late never replaces a newer one or the confirmation's.
    @ObservationIgnored private var previewGeneration = 0
    /// Bumped by Continue and by `wipeSecrets`, so a confirmation that
    /// finishes after a wipe writes nothing back.
    @ObservationIgnored private var confirmationGeneration = 0
    /// What `addressPreview` was derived from on the phrase step.
    private(set) var addressPreviewKey: ImportPreviewKey?

    init(
        mode: Mode,
        services: WalletServices,
        existingWalletCount: Int = 0,
        onFinished: @escaping (Wallet) -> Void
    ) {
        self.mode = mode
        self.services = services
        self.existingWalletCount = existingWalletCount
        self.onFinished = onFinished
        vaultInitialized = mode != .firstRun
        walletName = existingWalletCount == 0 ? "My Wallet" : "Wallet \(existingWalletCount + 1)"
        let wallets = services.wallets
        phraseEntry = PhraseEntryModel(wordList: wallets.mnemonicWordList) { words in
            await wallets.validateMnemonic(words)
        }
    }

    // MARK: Derived state

    var passwordStrength: PasswordStrength { PasswordPolicy.evaluate(password) }
    var passwordsMatch: Bool { !passwordConfirmation.isEmpty && password == passwordConfirmation }
    var canSubmitPassword: Bool { passwordStrength >= .fair && passwordsMatch && !isWorking }

    /// What to tell the user about the confirmation field, if anything.
    var passwordMismatchMessage: String? {
        guard !passwordConfirmation.isEmpty, password != passwordConfirmation else { return nil }
        return "The passwords do not match."
    }

    var canGoBack: Bool { !history.isEmpty && !isWorking }

    /// Steps shown in the side panel for the chosen path.
    var outline: [Step] {
        var steps: [Step] = []
        if mode == .firstRun { steps += [.password] }
        if let path {
            switch path {
            case .create: steps += [.phraseReveal, .phraseVerify]
            default: steps += [path.firstStep]
            }
            steps += [.confirm]
        }
        return steps
    }

    var isSeedValid: Bool {
        let cleaned = seedHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digits = cleaned.hasPrefix("0x") ? String(cleaned.dropFirst(2)) : cleaned
        return digits.count == 64 && digits.allSatisfy(\.isHexDigit)
    }

    var canContinueImport: Bool {
        guard !isWorking else { return false }
        switch step {
        case .importPhrase: return phraseEntry.isValid
        case .importSeed: return isSeedValid
        case .importJSON: return jsonData != nil && !jsonPassword.isEmpty
        case .watchOnly:
            return !watchSubstrateAddress.trimmingCharacters(in: .whitespaces).isEmpty
                || !watchEVMAddress.trimmingCharacters(in: .whitespaces).isEmpty
        default: return false
        }
    }

    var canFinish: Bool {
        !walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingSource != nil && !isWorking
    }

    // MARK: Navigation

    private func go(to next: Step) {
        history.append(step)
        step = next
        errorMessage = nil
    }

    func back() {
        guard canGoBack, let previous = history.popLast() else { return }
        // Leaving the phrase hides it again; leaving the Touch ID offer declines it.
        isPhraseRevealed = false
        if step == .biometrics { clearPassword() }
        errorMessage = nil
        step = previous
        if previous == .welcome {
            path = nil
            derivation = .standard
        }
    }

    /// The user picked how to add a wallet. Every flow starts from the
    /// standard derivation: options set on an import screen never carry
    /// over into another flow, and a wallet created here always uses the
    /// standard ones (the create flow has no Advanced options).
    func choose(_ path: Path) async {
        self.path = path
        derivation = .standard
        addressPreview = nil
        addressPreviewKey = nil
        pendingSource = nil
        errorMessage = nil
        if !vaultInitialized {
            go(to: .password)
        } else {
            await enterPath()
        }
    }

    private func enterPath() async {
        guard let path else { return }
        go(to: path.firstStep)
        if path == .create, phrase.isEmpty {
            await generatePhrase()
        }
    }

    // MARK: App password and Touch ID

    func submitPassword() async {
        guard canSubmitPassword else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await services.vault.initialize(password: password)
            vaultInitialized = true
            // The password step cannot be revisited once it is set.
            history = [.welcome]
            errorMessage = nil
            biometrics = await services.vault.biometricsAvailability()
            if biometrics == .available {
                step = .biometrics
            } else {
                clearPassword()
                await enterPathAfterVaultSetup()
            }
        } catch {
            errorMessage = ErrorText.message(for: error)
        }
    }

    func enableBiometrics() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await services.vault.setBiometricsEnabled(true, password: password)
            biometrics = .enabled
            clearPassword()
            await enterPathAfterVaultSetup()
        } catch {
            errorMessage = ErrorText.message(for: error)
        }
    }

    func skipBiometrics() async {
        clearPassword()
        await enterPathAfterVaultSetup()
    }

    private func enterPathAfterVaultSetup() async {
        guard let path else {
            step = .welcome
            return
        }
        // "Back" from the first wallet step returns to the choice of path.
        history = [.welcome]
        step = path.firstStep
        errorMessage = nil
        if path == .create, phrase.isEmpty {
            await generatePhrase()
        }
    }

    private func clearPassword() {
        password = ""
        passwordConfirmation = ""
    }

    // MARK: Create

    func generatePhrase() async {
        isWorking = true
        defer { isWorking = false }
        isPhraseRevealed = false
        verification = nil
        backupVerified = false
        do {
            phrase = try await services.wallets.generateMnemonic(length: phraseLength)
            errorMessage = nil
        } catch {
            phrase = []
            errorMessage = ErrorText.message(for: error)
        }
    }

    func setPhraseLength(_ length: MnemonicLength) async {
        guard length != phraseLength else { return }
        phraseLength = length
        await generatePhrase()
    }

    func hidePhrase() {
        isPhraseRevealed = false
    }

    /// From the phrase to the backup check.
    func beginVerification() {
        guard !phrase.isEmpty else { return }
        isPhraseRevealed = false
        verification = PhraseVerification(words: phrase, wordList: phraseEntry.wordList)
        go(to: .phraseVerify)
    }

    /// The check passed: the wallet will be marked as backed up.
    func completeVerification() async {
        guard verification?.isComplete == true else { return }
        backupVerified = true
        await prepareConfirmation(source: .created(words: phrase, options: .standard))
    }

    /// Skip the check; the wallet keeps a backup warning until it is done.
    func backUpLater() async {
        backupVerified = false
        await prepareConfirmation(source: .created(words: phrase, options: .standard))
    }

    // MARK: Import

    func setJSON(data: Data, fileName: String) {
        jsonData = data
        jsonFileName = fileName
        errorMessage = nil
    }

    func clearJSON() {
        jsonData = nil
        jsonFileName = nil
    }

    /// Reads a dropped or chosen keystore file. Files over 1 MB are refused.
    func loadJSON(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard data.count <= 1_048_576 else {
                errorMessage = "That file is too large to be a wallet backup."
                return
            }
            guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
                errorMessage = "That file is not a JSON backup."
                return
            }
            setJSON(data: data, fileName: url.lastPathComponent)
        } catch {
            errorMessage = "The file could not be read."
        }
    }

    private var importSource: WalletImportSource? {
        switch step {
        case .importPhrase:
            return .mnemonic(words: phraseEntry.normalizedWords, options: derivation)
        case .importSeed:
            return .seed(hex: seedHex.trimmingCharacters(in: .whitespacesAndNewlines), ecosystem: seedEcosystem, options: derivation)
        case .importJSON:
            guard let jsonData else { return nil }
            return .json(data: jsonData, password: jsonPassword)
        case .watchOnly:
            let substrate = watchSubstrateAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            let evm = watchEVMAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            return .watchOnly(substrateAddress: substrate.isEmpty ? nil : substrate, evmAddress: evm.isEmpty ? nil : evm)
        default:
            return nil
        }
    }

    func continueImport() async {
        guard canContinueImport, let source = importSource else { return }
        await prepareConfirmation(source: source)
    }

    /// Asks the engine which addresses the source gives and moves to the
    /// last step. Stays put, with the reason, if the source is not usable.
    private func prepareConfirmation(source: WalletImportSource) async {
        previewGeneration += 1
        confirmationGeneration += 1
        let generation = confirmationGeneration
        let key = livePreviewKey
        isWorking = true
        defer { isWorking = false }
        do {
            let preview = try await services.wallets.previewAddresses(for: source)
            guard generation == confirmationGeneration else { return }
            addressPreview = preview
            addressPreviewKey = key
            pendingSource = source
            go(to: .confirm)
        } catch {
            guard generation == confirmationGeneration else { return }
            errorMessage = ErrorText.message(for: error)
        }
    }

    /// The validated words and exact options on the phrase step; nil until
    /// the phrase is valid.
    var livePreviewKey: ImportPreviewKey? {
        guard step == .importPhrase, phraseEntry.isValid else { return nil }
        return ImportPreviewKey(words: phraseEntry.normalizedWords, options: ExactDerivationOptions(derivation))
    }

    /// The preview of exactly the words and options on screen, or nil while
    /// it is being derived. A preview of earlier input is never shown.
    var livePreview: WalletAddressPreview? {
        guard let key = livePreviewKey, key == addressPreviewKey else { return nil }
        return addressPreview
    }

    /// Refreshes the preview after the words or a derivation option changed.
    /// The result is kept only if it still belongs to the input on screen.
    func refreshPreview() async {
        guard let key = livePreviewKey else {
            // The phrase is no longer valid (Clear, an edit): forget the
            // preview and what it was derived from.
            if step == .importPhrase { forgetPreview() }
            return
        }
        previewGeneration += 1
        let generation = previewGeneration
        let preview = try? await services.wallets.previewAddresses(for: .mnemonic(words: key.words, options: key.options.options))
        guard generation == previewGeneration, livePreviewKey == key else { return }
        addressPreview = preview
        addressPreviewKey = key
    }

    // MARK: Finish

    /// Stores the wallet. The engine stores a phrase created here as not
    /// backed up and everything else as backed up; a created wallet is
    /// marked backed up only when the check passed.
    func finish() async {
        guard canFinish, let source = pendingSource else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let name = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
            var wallet = try await services.wallets.addWallet(name: name, source: source)
            if path == .create, backupVerified, !wallet.isBackedUp {
                do {
                    try await services.wallets.markBackedUp(wallet.id)
                    wallet.isBackedUp = true
                } catch {
                    // The wallet exists; the reminder simply stays until the check is repeated.
                }
            }
            wipeSecrets()
            onFinished(wallet)
        } catch {
            errorMessage = ErrorText.message(for: error)
        }
    }

    /// Drops every secret the flow held.
    /// Drops the address preview and the words and options it came from.
    private func forgetPreview() {
        previewGeneration += 1
        addressPreview = nil
        addressPreviewKey = nil
    }

    func wipeSecrets() {
        forgetPreview()
        confirmationGeneration += 1
        derivation = .standard
        phrase = []
        verification = nil
        isPhraseRevealed = false
        phraseEntry.clear()
        seedHex = ""
        jsonData = nil
        jsonFileName = nil
        jsonPassword = ""
        pendingSource = nil
        clearPassword()
    }
}
