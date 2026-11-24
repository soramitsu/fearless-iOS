import DesignSystem
import SwiftUI
import UniformTypeIdentifiers
import WalletCore

// MARK: - Recovery phrase

struct ImportPhraseStep: View {
    @Bindable var model: OnboardingModel
    let compact: Bool
    var onCancel: (() -> Void)?

    @State private var showAdvanced = false
    @State private var secretFields = SecretFieldGroup()
    @Environment(\.staticRendering) private var staticRendering

    private var entry: PhraseEntryModel { model.phraseEntry }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 100), spacing: 8), count: entry.wordCount > 12 ? 4 : 3)
    }

    var body: some View {
        StepScaffold(
            title: "Enter Your Recovery Phrase",
            subtitle: "Type the words in order, or paste the whole phrase into any field. The same phrase gives the same addresses as on iPhone, Android and the browser extension.",
            compact: compact
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Picker("Words", selection: Binding(get: { entry.wordCount }, set: { entry.setWordCount($0) })) {
                        ForEach(PhraseEntryModel.lengths, id: \.self) { count in
                            Text("\(count) words").tag(count)
                        }
                    }
                    .frame(width: 150)
                    .labelsHidden()
                    .accessibilityLabel("Number of words")
                    Button {
                        if let text = Clipboard.shared.string() { entry.setText(text, at: 0) }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .help("Paste a whole phrase from the clipboard")
                    Button("Clear") { entry.clear() }
                        .disabled(entry.filledCount == 0)
                    Spacer()
                    Text("\(entry.filledCount) of \(entry.wordCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(entry.filledCount) of \(entry.wordCount) words entered")
                }
                .controlSize(.small)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<entry.wordCount, id: \.self) { index in
                        wordField(index)
                    }
                }

                suggestionBar

                if let problem = entry.problem {
                    InlineMessage(problem, kind: .error)
                } else if entry.isValidating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Checking the phrase…").font(.callout).foregroundStyle(.secondary)
                    }
                } else if entry.isValid {
                    InlineMessage("The phrase is valid.", kind: .success)
                }

                DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                    DerivationOptionsForm(options: $model.derivation, showsEVM: true)
                        .padding(.top, 8)
                }
                // Byte for byte: é and e + ◌́ are equal strings but derive different accounts.
                .onChange(of: ExactDerivationOptions(model.derivation)) { _, _ in Task { await model.refreshPreview() } }
                .onChange(of: entry.isValid) { _, _ in Task { await model.refreshPreview() } }

                if entry.isValid, let preview = model.addressPreview {
                    AddressPreviewCard(preview: preview)
                }
                if let error = model.errorMessage {
                    InlineMessage(error, kind: .error)
                }
            }
        } footer: {
            StepBackButtons(model: model, onCancel: onCancel)
            Spacer()
            StepProgress(isWorking: model.isWorking)
            Button("Continue") { continueImport() }
                .brandProminentButton()
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canContinueImport)
        }
        .environment(\.secretFieldGroup, secretFields)
        .background(CaptureProtection(isActive: showsSecrets && !staticRendering))
        .onAppear {
            if entry.focusedIndex == nil { entry.focusedIndex = 0 }
        }
    }

    private func wordField(_ index: Int) -> some View {
        let unknown = entry.isUnknown(index)
        let focused = entry.focusedIndex == index
        return HStack(spacing: 5) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
                .accessibilityHidden(true)
            // An AppKit field with its own editor: Roman-script input sources
            // only, and AppKit's spelling, grammar, correction, replacement,
            // completion, smart punctuation, prediction, math completion,
            // Writing Tools, Share and Look Up off. (The Roman mode of an input
            // method can still receive the keys.)
            SecretTextField(
                entry: .recoveryWord,
                text: Binding(get: { entry.words[safe: index] ?? "" }, set: { entry.setText($0, at: index) }),
                style: .plain,
                accessibilityLabel: unknown ? "Word \(index + 1), not in the word list" : "Word \(index + 1)",
                isFocused: focused,
                focusID: index,
                onFocusChange: { isFocused in focusChanged(isFocused, at: index) },
                onCommand: { command in handle(command, at: index) },
                onPaste: { text in pasted(text, at: index) }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    unknown ? BrandColor.failure : (focused ? BrandColor.accent : Color.primary.opacity(0.15)),
                    lineWidth: unknown || focused ? 1.5 : 0.5
                )
        }
        .overlay(alignment: .trailing) {
            if unknown {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(BrandColor.failure)
                    .padding(.trailing, 6)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Words from the list that start with what is typed in the focused field.
    private var suggestionBar: some View {
        let index = entry.focusedIndex ?? -1
        let suggestions = entry.suggestions(at: index)
        return HStack(spacing: 6) {
            if suggestions.isEmpty {
                Text("Suggestions appear here as you type. Press Tab to accept the first one.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(suggestions.enumerated()), id: \.element) { position, word in
                    Button {
                        entry.acceptSuggestion(word, at: index)
                    } label: {
                        Text(word).font(.system(.callout, design: .monospaced))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(position == 0 ? BrandColor.accent : nil)
                    .accessibilityLabel("Use \(word)")
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 24)
    }

    private func focusChanged(_ isFocused: Bool, at index: Int) {
        if isFocused {
            if entry.focusedIndex != index { entry.focusedIndex = index }
        } else if entry.focusedIndex == index {
            entry.focusedIndex = nil
        }
    }

    /// Space and Return accept the first suggestion or move on; Tab accepts
    /// the first suggestion, or moves between the words like Shift-Tab.
    /// Keyboard focus moves before the key returns, so the next key lands
    /// in the next word.
    private func handle(_ command: SecretTextField.Command, at index: Int) -> Bool {
        switch command {
        case .space, .submit:
            acceptOrAdvance(index)
            return true
        case .tab:
            if let first = entry.suggestions(at: index).first {
                entry.acceptSuggestion(first, at: index)
                secretFields.move(to: entry.focusedIndex)
                return true
            }
            guard index + 1 < entry.wordCount else { return false }
            moveFocus(to: index + 1)
            return true
        case .backtab:
            guard index > 0 else { return false }
            moveFocus(to: index - 1)
            return true
        }
    }

    private func moveFocus(to index: Int?) {
        entry.focusedIndex = index
        secretFields.move(to: index)
    }

    /// Several words pasted or dropped into a field go to the grid as they
    /// are, replacing the field's text rather than joining it; one word is
    /// pasted as usual.
    private func pasted(_ text: String, at index: Int) -> Bool {
        guard PhraseEntryModel.tokens(in: text).count > 1 else { return false }
        entry.setText(text, at: index)
        secretFields.move(to: entry.focusedIndex)
        return true
    }

    private func acceptOrAdvance(_ index: Int) {
        let text = entry.words[safe: index] ?? ""
        let suggestions = entry.suggestions(at: index)
        if !text.isEmpty, !entry.wordList.contains(text), let first = suggestions.first {
            entry.acceptSuggestion(first, at: index)
            secretFields.move(to: entry.focusedIndex)
        } else if index + 1 < entry.wordCount {
            moveFocus(to: index + 1)
        } else if model.canContinueImport {
            continueImport()
        }
    }

    private func continueImport() {
        secretFields.finishComposition()
        Task { await model.continueImport() }
    }

    /// Typed words, or a path with a password, are kept out of screenshots
    /// and screen sharing ("remote support" scams ask to watch this screen).
    private var showsSecrets: Bool {
        entry.filledCount > 0
            || DerivationPath.holdsPassword(model.derivation.substrateDerivationPath)
            || DerivationPath.holdsPassword(model.derivation.evmDerivationPath)
    }
}

extension Array {
    /// The element at `index`, or nil when it is out of range.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Crypto type and derivation paths. The defaults match the Fearless apps
/// on iPhone and Android. A path may end in a `///password`, so both path
/// fields are secret fields that keep every input source (for Unicode
/// passwords) and pass the text to derivation exactly as typed.
struct DerivationOptionsForm: View {
    @Binding var options: DerivationOptions
    let showsEVM: Bool

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("Polkadot key type").gridColumnAlignment(.trailing)
                Picker("Polkadot key type", selection: $options.substrateCryptoType) {
                    ForEach(CryptoType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 300, alignment: .leading)
            }
            GridRow {
                Text("Polkadot derivation path")
                SecretTextField(
                    entry: .derivationPath,
                    placeholder: "None, for example //polkadot",
                    text: $options.substrateDerivationPath,
                    accessibilityLabel: "Polkadot derivation path"
                )
                .frame(maxWidth: 300)
            }
            if showsEVM {
                GridRow {
                    Text("Ethereum derivation path")
                    HStack(spacing: 6) {
                        SecretTextField(
                            entry: .derivationPath,
                            placeholder: DerivationOptions.defaultEVMPath,
                            text: $options.evmDerivationPath,
                            accessibilityLabel: "Ethereum derivation path"
                        )
                        .frame(maxWidth: 300)
                        if options.evmDerivationPath != DerivationOptions.defaultEVMPath {
                            Button("Reset") { options.evmDerivationPath = DerivationOptions.defaultEVMPath }
                                .controlSize(.small)
                        }
                    }
                }
            }
            if DerivationPath.hasLineBreak(options.substrateDerivationPath)
                || (showsEVM && DerivationPath.hasLineBreak(options.evmDerivationPath)) {
                GridRow {
                    Color.clear.frame(width: 1, height: 1)
                    // Kept exactly as entered, since derivation uses every character.
                    InlineMessage("A derivation path contains a line break. Remove it unless the wallet was made with one.", kind: .warning)
                }
            }
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                Text("Leave these as they are unless the wallet was made with other settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }
}

/// The addresses an import would produce.
struct AddressPreviewCard: View {
    let preview: WalletAddressPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Addresses of this wallet")
                .font(.callout.weight(.medium))
            if let substrate = preview.substrate {
                row(name: "Polkadot", iconName: "Polkadot", accent: "#E6007A", address: substrate)
            }
            if let evm = preview.evm {
                row(name: "Ethereum", iconName: "Ethereum", accent: "#627EEA", address: evm)
            }
            if preview.substrate == nil, preview.evm == nil {
                Text("No address could be derived.").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 12)
    }

    private func row(name: String, iconName: String, accent: String, address: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ChainIconView(name: name, iconName: iconName, accentHex: accent, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.callout.weight(.medium))
                FullAddressText(address)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            CopyButton(value: address, label: "Copy \(name) Address")
        }
    }
}

// MARK: - Raw seed

struct ImportSeedStep: View {
    @Bindable var model: OnboardingModel
    let compact: Bool

    @State private var ownVisibility = false
    private let visibility: Binding<Bool>?
    @State private var secretFields = SecretFieldGroup()
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.staticRendering) private var staticRendering

    /// `isVisible` is for tests; nil keeps the eye button's state here.
    init(model: OnboardingModel, compact: Bool, isVisible: Binding<Bool>? = nil) {
        self.model = model
        self.compact = compact
        visibility = isVisible
    }

    private var isVisible: Bool {
        get { visibility?.wrappedValue ?? ownVisibility }
        nonmutating set {
            if let visibility { visibility.wrappedValue = newValue } else { ownVisibility = newValue }
        }
    }

    private var secretName: String {
        model.seedEcosystem == .substrate ? "Seed" : "Private key"
    }

    var body: some View {
        StepScaffold(
            title: "Import a Raw Seed",
            subtitle: "A raw seed (Polkadot ecosystem) or private key (Ethereum) is 32 bytes written as 64 hexadecimal characters. A seed gives one account, not both.",
            compact: compact
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Account type", selection: $model.seedEcosystem) {
                    ForEach(Ecosystem.allCases, id: \.self) { ecosystem in
                        Text(ecosystem.displayName).tag(ecosystem)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
                .accessibilityLabel("Account type")

                VStack(alignment: .leading, spacing: 6) {
                    Text(secretName).font(.callout.weight(.medium))
                    HStack(spacing: 6) {
                        // The secure field is the only editor, shown or not:
                        // it accepts paste but no copy, and no text service
                        // or input method sees the hex.
                        SecureField("0x…", text: $model.seedHex)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                            .accessibilityLabel(secretName)
                        Button {
                            isVisible.toggle()
                        } label: {
                            Image(systemName: isVisible ? "eye.slash" : "eye")
                        }
                        .help(isVisible ? "Hide" : "Show")
                        .accessibilityLabel(isVisible ? "Hide \(secretName.lowercased())" : "Show \(secretName.lowercased())")
                    }
                    if isVisible, !model.seedHex.isEmpty {
                        RevealedSecretText(name: secretName, value: model.seedHex)
                    }
                    if !model.seedHex.isEmpty, !model.isSeedValid {
                        InlineMessage("Enter exactly 64 hexadecimal characters (0–9, a–f), with or without 0x.", kind: .error)
                    }
                }
                if model.seedEcosystem == .substrate {
                    DerivationOptionsForm(options: $model.derivation, showsEVM: false)
                }
                if let error = model.errorMessage {
                    InlineMessage(error, kind: .error)
                }
            }
        } footer: {
            StepBackButtons(model: model)
            Spacer()
            StepProgress(isWorking: model.isWorking)
            Button("Continue") {
                secretFields.finishComposition()
                Task { await model.continueImport() }
            }
            .brandProminentButton()
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canContinueImport)
        }
        .environment(\.secretFieldGroup, secretFields)
        .background(CaptureProtection(
            isActive: (isVisible || DerivationPath.holdsPassword(model.derivation.substrateDerivationPath)) && !staticRendering
        ))
        .onChange(of: controlActiveState) { _, state in
            if state != .key, !staticRendering { isVisible = false }
        }
    }
}

/// A revealed secret as read-only text: it cannot be selected, copied or
/// edited. VoiceOver reads it character by character.
struct RevealedSecretText: View {
    let name: String
    let value: String

    var body: some View {
        Text(value)
            .font(.system(.callout, design: .monospaced))
            .textSelection(.disabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(name), shown")
            .accessibilityValue(Text(value).speechSpellsOutCharacters())
    }
}

// MARK: - JSON backup

struct ImportJSONStep: View {
    @Bindable var model: OnboardingModel
    let compact: Bool

    @State private var isChoosingFile = false
    @State private var isTargeted = false

    var body: some View {
        StepScaffold(
            title: "Import a JSON Backup",
            subtitle: "Choose the keystore file exported from Polkadot.js or Fearless and enter the password it was exported with.",
            compact: compact
        ) {
            VStack(alignment: .leading, spacing: 14) {
                dropZone
                VStack(alignment: .leading, spacing: 6) {
                    Text("Backup password").font(.callout.weight(.medium))
                    SecureField("The password of the backup file", text: $model.jsonPassword)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                        .onSubmit { Task { await model.continueImport() } }
                        .accessibilityLabel("Backup password")
                    Text("This is not your app password.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error = model.errorMessage {
                    InlineMessage(error, kind: .error)
                }
            }
        } footer: {
            StepBackButtons(model: model)
            Spacer()
            StepProgress(isWorking: model.isWorking)
            Button("Continue") { Task { await model.continueImport() } }
                .brandProminentButton()
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canContinueImport)
        }
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { model.loadJSON(from: url) }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            if let name = model.jsonFileName {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(BrandColor.accent)
                Text(name).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                Button("Choose Another File…") { isChoosingFile = true }
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("Drop a .json backup here")
                    .font(.callout.weight(.medium))
                Button("Choose File…") { isChoosingFile = true }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isTargeted ? BrandColor.accent.opacity(0.10) : Color.primary.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isTargeted ? BrandColor.accent : Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            JSONDrop.handle(providers) { url in model.loadJSON(from: url) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.jsonFileName.map { "Backup file \($0)" } ?? "Backup file drop area")
    }
}

// MARK: - Watch-only

struct WatchOnlyStep: View {
    @Bindable var model: OnboardingModel
    let compact: Bool

    var body: some View {
        StepScaffold(
            title: "Watch an Address",
            subtitle: "A watch-only wallet shows balances and history of an address. It holds no keys, so it cannot send.",
            compact: compact
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Polkadot-ecosystem address").font(.callout.weight(.medium))
                    TextField("Polkadot, Kusama or another Substrate address", text: $model.watchSubstrateAddress)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .accessibilityLabel("Polkadot-ecosystem address")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ethereum address").font(.callout.weight(.medium))
                    TextField("0x…", text: $model.watchEVMAddress)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .accessibilityLabel("Ethereum address")
                }
                Text("Enter one or both.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = model.errorMessage {
                    InlineMessage(error, kind: .error)
                }
            }
        } footer: {
            StepBackButtons(model: model)
            Spacer()
            StepProgress(isWorking: model.isWorking)
            Button("Continue") { Task { await model.continueImport() } }
                .brandProminentButton()
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canContinueImport)
        }
    }
}

// MARK: - Name and confirm

struct ConfirmStep: View {
    @Bindable var model: OnboardingModel
    let compact: Bool

    @FocusState private var nameFocused: Bool

    private var actionTitle: String {
        switch model.path {
        case .create?: return "Create Wallet"
        case .watchOnly?: return "Add Wallet"
        default: return "Import Wallet"
        }
    }

    var body: some View {
        StepScaffold(
            title: "Name Your Wallet",
            subtitle: "Check the addresses, then give the wallet a name you will recognise. You can rename it later in Settings.",
            compact: compact
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wallet name").font(.callout.weight(.medium))
                    TextField("My Wallet", text: $model.walletName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                        .focused($nameFocused)
                        .onSubmit { Task { await model.finish() } }
                        .accessibilityLabel("Wallet name")
                }
                if let preview = model.addressPreview {
                    AddressPreviewCard(preview: preview)
                }
                if model.path == .create, !model.backupVerified {
                    InlineMessage("This wallet is not backed up yet. Fearless will remind you until you confirm the recovery phrase.", kind: .warning, boxed: true)
                }
                if let error = model.errorMessage {
                    InlineMessage(error, kind: .error)
                }
            }
        } footer: {
            StepBackButtons(model: model)
            Spacer()
            StepProgress(isWorking: model.isWorking)
            Button(actionTitle) { Task { await model.finish() } }
                .brandProminentButton()
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canFinish)
        }
        .onAppear { nameFocused = true }
    }
}

/// The Add Wallet sheet over the main window.
struct AddWalletSheet: View {
    let model: OnboardingModel
    let onCancel: () -> Void

    var body: some View {
        OnboardingStepView(model: model, compact: true, onCancel: onCancel)
            .frame(width: 680, height: 600)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                JSONDrop.handle(providers) { url in
                    Task {
                        if model.step == .welcome { await model.choose(.importJSON) }
                        if model.step == .importJSON { model.loadJSON(from: url) }
                    }
                }
            }
    }
}
