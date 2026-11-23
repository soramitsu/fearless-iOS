import DesignSystem
import SwiftUI
import WalletCore

/// Title, explanation, scrolling content and a footer of buttons: the frame
/// every setup step shares.
struct StepScaffold<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String
    let compact: Bool
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.brandDisplay(compact ? 22 : 27, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 600, alignment: .leading)
            ScrollView {
                content
                    .frame(maxWidth: 600, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    .padding(.trailing, 4)
            }
            .scrollBounceBehavior(.basedOnSize)
            Divider()
            HStack(spacing: 10) {
                footer
            }
            .controlSize(compact ? .regular : .large)
            .padding(.top, 14)
        }
        .padding(.horizontal, compact ? 28 : 48)
        .padding(.top, compact ? 26 : 60)
        .padding(.bottom, compact ? 18 : 24)
    }
}

/// The content of the current setup step. Used full-window on first launch
/// and inside the Add Wallet sheet.
struct OnboardingStepView: View {
    @Bindable var model: OnboardingModel
    var compact = false
    var onCancel: (() -> Void)?

    var body: some View {
        Group {
            switch model.step {
            case .welcome: ChooserStep(model: model, compact: compact, onCancel: onCancel)
            case .password: PasswordStep(model: model, compact: compact)
            case .biometrics: BiometricsStep(model: model, compact: compact)
            case .phraseReveal: PhraseRevealStep(model: model, compact: compact, onCancel: onCancel)
            case .phraseVerify: PhraseVerifyStep(model: model, compact: compact)
            case .importPhrase: ImportPhraseStep(model: model, compact: compact, onCancel: onCancel)
            case .importSeed: ImportSeedStep(model: model, compact: compact)
            case .importJSON: ImportJSONStep(model: model, compact: compact)
            case .watchOnly: WatchOnlyStep(model: model, compact: compact)
            case .confirm: ConfirmStep(model: model, compact: compact)
            }
        }
        .tint(BrandColor.accent)
    }
}

/// Back and Cancel, as far as each applies.
struct StepBackButtons: View {
    let model: OnboardingModel
    var onCancel: (() -> Void)?

    var body: some View {
        if model.canGoBack {
            Button("Back") { model.back() }
                .keyboardShortcut(.cancelAction)
        } else if let onCancel {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
        }
    }
}

/// A spinner beside the footer buttons while the engine works.
struct StepProgress: View {
    let isWorking: Bool

    var body: some View {
        if isWorking {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Working")
        }
    }
}

// MARK: - Choose how to add a wallet

struct ChooserStep: View {
    let model: OnboardingModel
    let compact: Bool
    var onCancel: (() -> Void)?

    var body: some View {
        StepScaffold(
            title: model.mode == .addWallet ? "Add a Wallet" : "Add Your First Wallet",
            subtitle: "Create a new wallet or bring in one you already have. Every wallet is encrypted with your app password.",
            compact: compact
        ) {
            VStack(spacing: 8) {
                ForEach(OnboardingModel.Path.allCases) { path in
                    Button {
                        Task { await model.choose(path) }
                    } label: {
                        HStack(spacing: 12) {
                            ChoiceLabel(title: path.title, detail: path.detail, symbol: path.symbol, onBrand: false)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .background(BrandColor.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
                    .disabled(model.isWorking)
                }
                if let error = model.errorMessage {
                    InlineMessage(error, kind: .error)
                }
            }
        } footer: {
            StepBackButtons(model: model, onCancel: onCancel)
            Spacer()
            StepProgress(isWorking: model.isWorking)
        }
    }
}

// MARK: - App password

struct PasswordStep: View {
    @Bindable var model: OnboardingModel
    let compact: Bool

    private enum Field { case password, confirmation }
    @FocusState private var focus: Field?

    var body: some View {
        StepScaffold(
            title: "Choose an App Password",
            subtitle: "It unlocks Fearless on this Mac and encrypts every key. Nobody can reset it: if you forget it, you restore your wallets from their recovery phrases.",
            compact: compact
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Password").font(.callout.weight(.medium))
                    SecureField("At least 8 characters", text: $model.password)
                        .textFieldStyle(.roundedBorder)
                        .focused($focus, equals: .password)
                        .onSubmit { focus = .confirmation }
                        .frame(maxWidth: 360)
                        .accessibilityLabel("Password")
                    PasswordStrengthMeter(strength: model.passwordStrength, isEmpty: model.password.isEmpty)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Confirm password").font(.callout.weight(.medium))
                    SecureField("Type it again", text: $model.passwordConfirmation)
                        .textFieldStyle(.roundedBorder)
                        .focused($focus, equals: .confirmation)
                        .onSubmit { Task { await model.submitPassword() } }
                        .frame(maxWidth: 360)
                        .accessibilityLabel("Confirm password")
                    if let mismatch = model.passwordMismatchMessage {
                        InlineMessage(mismatch, kind: .error)
                    } else if model.passwordsMatch {
                        InlineMessage("The passwords match.", kind: .success)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    GuidanceRow(met: model.password.count >= PasswordPolicy.minimumLength, text: "At least \(PasswordPolicy.minimumLength) characters")
                    GuidanceRow(met: model.passwordStrength >= .fair, text: "A mix of upper and lower case, numbers or symbols; 12 or more characters is stronger")
                    GuidanceRow(met: model.passwordStrength >= .fair, text: "Not a common word such as “password” or “polkadot”")
                }
                .padding(.top, 4)
                if let error = model.errorMessage {
                    InlineMessage(error, kind: .error)
                }
            }
        } footer: {
            StepBackButtons(model: model)
            Spacer()
            StepProgress(isWorking: model.isWorking)
            Button("Continue") { Task { await model.submitPassword() } }
                .brandProminentButton()
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSubmitPassword)
        }
        .onAppear { focus = .password }
    }
}

/// One line of password guidance with a mark that fills in when it is met.
struct GuidanceRow: View {
    let met: Bool
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? BrandColor.gain : Color.secondary)
                .font(.caption)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityValue(met ? "Met" : "Not met")
    }
}

// MARK: - Touch ID

struct BiometricsStep: View {
    let model: OnboardingModel
    let compact: Bool

    var body: some View {
        StepScaffold(
            title: "Unlock with Touch ID",
            subtitle: "Use your fingerprint instead of typing the app password to unlock Fearless and approve transfers. You can change this in Settings at any time.",
            compact: compact
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "touchid")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(BrandColor.accent)
                    .accessibilityHidden(true)
                Text("Your password still works, and macOS asks for it after a restart or when fingerprints change.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let error = model.errorMessage {
                    InlineMessage(error, kind: .error)
                }
            }
        } footer: {
            Spacer()
            StepProgress(isWorking: model.isWorking)
            Button("Not Now") { Task { await model.skipBiometrics() } }
                .keyboardShortcut(.cancelAction)
                .disabled(model.isWorking)
            Button("Enable Touch ID") { Task { await model.enableBiometrics() } }
                .brandProminentButton()
                .keyboardShortcut(.defaultAction)
                .disabled(model.isWorking)
        }
    }
}

// MARK: - New phrase

struct PhraseRevealStep: View {
    @Bindable var model: OnboardingModel
    let compact: Bool
    var onCancel: (() -> Void)?

    var body: some View {
        StepScaffold(
            title: "Write Down Your Recovery Phrase",
            subtitle: "These words are your wallet. Write them on paper, in order, and keep the paper somewhere safe. Anyone who has them can take your funds, and nobody can restore them for you.",
            compact: compact
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Length", selection: Binding(
                    get: { model.phraseLength },
                    set: { length in Task { await model.setPhraseLength(length) } }
                )) {
                    Text("12 words").tag(MnemonicLength.words12)
                    Text("24 words").tag(MnemonicLength.words24)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .labelsHidden()
                .accessibilityLabel("Phrase length")
                .disabled(model.isWorking)

                if model.phrase.isEmpty {
                    if let error = model.errorMessage {
                        InlineMessage(error, kind: .error) {
                            Button("Try Again") { Task { await model.generatePhrase() } }
                        }
                    } else {
                        HStack(spacing: 8) {
                            CometLoader(size: 22)
                            Text("Making a new phrase…").foregroundStyle(.secondary)
                        }
                        .frame(height: 120)
                    }
                } else {
                    PhraseRevealPanel(words: model.phrase, isRevealed: $model.isPhraseRevealed)
                    InlineMessage("Never type these words into a website or share them in a chat. Fearless will never ask for them.", kind: .warning, boxed: true)
                }
            }
        } footer: {
            StepBackButtons(model: model, onCancel: onCancel)
            Spacer()
            StepProgress(isWorking: model.isWorking)
            Button("Back Up Later") { Task { await model.backUpLater() } }
                .disabled(model.phrase.isEmpty || model.isWorking)
                .help("Create the wallet now. Fearless keeps reminding you until the phrase is backed up.")
            Button("I Wrote It Down") { model.beginVerification() }
                .brandProminentButton()
                .keyboardShortcut(.defaultAction)
                .disabled(model.phrase.isEmpty || model.isWorking)
        }
    }
}

struct PhraseVerifyStep: View {
    let model: OnboardingModel
    let compact: Bool

    var body: some View {
        StepScaffold(
            title: "Check Your Backup",
            subtitle: "Choose the right word for each position from your written copy. This confirms the phrase can restore your wallet.",
            compact: compact
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let verification = model.verification {
                    PhraseVerifyPanel(verification: verification)
                }
                if let error = model.errorMessage {
                    InlineMessage(error, kind: .error)
                }
            }
        } footer: {
            StepBackButtons(model: model)
            Spacer()
            StepProgress(isWorking: model.isWorking)
            Button("Back Up Later") { Task { await model.backUpLater() } }
                .disabled(model.isWorking)
            Button("Continue") { Task { await model.completeVerification() } }
                .brandProminentButton()
                .keyboardShortcut(.defaultAction)
                .disabled(model.verification?.isComplete != true || model.isWorking)
        }
    }
}
