import DesignSystem
import SwiftUI
import WalletCore

/// Asks the user to prove presence before a sensitive action: the app
/// password, or Touch ID when it is enabled.
struct ApprovalField: View {
    @Binding var password: String
    let canUseBiometrics: Bool
    let isWorking: Bool
    let error: String?
    let actionTitle: String
    let canSubmit: Bool
    let submitPassword: () -> Void
    let submitBiometrics: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SecureField("App password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit { if canSubmit, !password.isEmpty { submitPassword() } }
                    .accessibilityLabel("App password")
                if canUseBiometrics {
                    Button {
                        submitBiometrics()
                    } label: {
                        Label("Touch ID", systemImage: "touchid")
                    }
                    .disabled(isWorking || !canSubmit)
                    .help("\(actionTitle) with Touch ID")
                }
            }
            if let error {
                InlineMessage(error, kind: .error)
            }
        }
        .onAppear { focused = true }
    }
}
