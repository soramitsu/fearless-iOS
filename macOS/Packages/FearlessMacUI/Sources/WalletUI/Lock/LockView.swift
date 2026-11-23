import DesignSystem
import SwiftUI
import WalletCore

/// The full-window lock screen.
struct LockView: View {
    @Bindable var model: LockModel

    @FocusState private var passwordFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            BrandBackdrop()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    SolarHalo(size: 176)
                    CrestBadge(size: 104)
                }
                Text("Fearless Is Locked")
                    .font(.brandDisplay(26, weight: .bold))
                    .foregroundStyle(BrandPalette.text)
                    .padding(.top, 20)
                    .accessibilityAddTraits(.isHeader)
                Text("Enter your app password to open your wallets.")
                    .font(.callout)
                    .foregroundStyle(BrandPalette.textMuted)
                    .padding(.top, 6)

                HStack(spacing: 8) {
                    SecureField("App password", text: $model.password)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .focused($passwordFocused)
                        .onSubmit { Task { await model.unlockWithPassword() } }
                        .disabled(model.isWorking)
                        .accessibilityLabel("App password")
                    Button {
                        Task { await model.unlockWithPassword() }
                    } label: {
                        if model.isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .controlSize(.large)
                    .brandProminentButton()
                    .disabled(!model.canUnlock)
                    .help("Unlock")
                    .accessibilityLabel("Unlock")
                }
                .frame(width: 300)
                .padding(.top, 24)
                .modifier(ShakeEffect(shakes: reduceMotion ? 0 : CGFloat(model.failedAttempts)))
                .animation(reduceMotion ? nil : .linear(duration: BrandMotion.d360), value: model.failedAttempts)

                Group {
                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(BrandPalette.gold)
                            .accessibilityLabel("Error: \(error)")
                    } else {
                        Text(" ")
                    }
                }
                .font(.callout)
                .frame(height: 22)
                .padding(.top, 10)

                if model.canUseBiometrics {
                    Button {
                        Task { await model.unlockWithBiometrics() }
                    } label: {
                        Label("Unlock with Touch ID", systemImage: "touchid")
                    }
                    .controlSize(.large)
                    .disabled(model.isWorking)
                    .padding(.top, 6)
                }
                Spacer()
                Button("Forgot password?") { model.beginErase() }
                    .buttonStyle(.link)
                    .foregroundStyle(BrandPalette.textSoft)
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, 40)
        }
        .environment(\.colorScheme, .dark)
        .tint(BrandPalette.pinkText)
        .task { await model.load() }
        .onAppear { passwordFocused = true }
        .onChange(of: model.failedAttempts) { _, _ in passwordFocused = true }
        .sheet(isPresented: $model.isShowingErase) {
            EraseConfirmationView(
                title: "Forgot Your Password?",
                message: "The app password cannot be reset. You can erase Fearless on this Mac and set it up again, then restore each wallet from its recovery phrase or backup file.",
                confirmation: $model.eraseConfirmation,
                canErase: model.canErase,
                isWorking: model.isErasing,
                error: model.eraseError,
                onErase: { Task { await model.eraseAll() } },
                onCancel: { model.cancelErase() }
            )
        }
    }
}

/// A short horizontal shake for a wrong password.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 9 * sin(shakes * .pi * 4), y: 0))
    }
}

/// Erasing everything needs a typed confirmation.
struct EraseConfirmationView: View {
    let title: String
    let message: String
    @Binding var confirmation: String
    let canErase: Bool
    let isWorking: Bool
    let error: String?
    let onErase: () -> Void
    let onCancel: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(BrandColor.failure)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline)
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            InlineMessage("Erasing deletes every wallet, key and setting stored by Fearless on this Mac. Wallets without a backup are lost for good.", kind: .error, boxed: true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Type \(LockModel.eraseConfirmationWord) to confirm")
                    .font(.callout.weight(.medium))
                TextField(LockModel.eraseConfirmationWord, text: $confirmation)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .frame(width: 200)
                    .accessibilityLabel("Type \(LockModel.eraseConfirmationWord) to confirm")
            }
            if let error {
                InlineMessage(error, kind: .error)
            }
            HStack {
                Spacer()
                if isWorking { ProgressView().controlSize(.small) }
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Erase All Data", role: .destructive, action: onErase)
                    .disabled(!canErase)
            }
        }
        .padding(22)
        .frame(width: 460)
        .onAppear { focused = true }
    }
}
