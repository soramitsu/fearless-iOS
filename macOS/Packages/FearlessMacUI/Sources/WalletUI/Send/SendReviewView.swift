import DesignSystem
import SwiftUI
import WalletCore

/// Everything about the transfer before it is approved: the whole recipient
/// address, the exact amount, the fee and the total.
struct SendReviewView: View {
    @Bindable var model: SendModel

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let request = model.preparation?.request, let row = model.selectedRow {
                        amountHeader(request, row)
                        VStack(alignment: .leading, spacing: 10) {
                            ReviewRow("From") { Text(model.wallet.name) }
                            Divider()
                            ReviewRow("To") {
                                FullAddressText(request.recipient)
                            }
                            Divider()
                            ReviewRow("Network") {
                                HStack(spacing: 6) {
                                    ChainIconView(name: row.chain.name, iconName: row.chain.iconName, accentHex: row.chain.accentHex, size: 16)
                                    Text(row.chain.name)
                                }
                            }
                            Divider()
                            ReviewRow("Network fee") {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(model.feeText ?? "—").monospacedDigit()
                                    if let fiat = model.feeFiatText {
                                        Text(fiat).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                                    }
                                }
                            }
                            Divider()
                            ReviewRow("Total") {
                                Text(totalText(request, row)).fontWeight(.semibold).monospacedDigit()
                            }
                            if model.isSubstrate {
                                Divider()
                                ReviewRow("Account") {
                                    Text(request.keepAlive ? "Kept open after the transfer" : "May be closed by this transfer")
                                        .foregroundStyle(request.keepAlive ? Color.secondary : BrandColor.warning)
                                }
                            }
                        }
                        .font(.callout)
                        .card(padding: 14)

                        InlineMessage("Transfers cannot be undone. Check every character of the address.", kind: .warning)

                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel("Approve with your app password\(model.canApproveWithBiometrics ? " or Touch ID" : "")")
                            ApprovalField(
                                password: $model.approvalPassword,
                                canUseBiometrics: model.biometrics == .enabled,
                                isWorking: model.isSubmitting,
                                error: model.approvalError,
                                actionTitle: "Approve",
                                canSubmit: !model.isSubmitting,
                                submitPassword: { Task { await model.approveWithPassword() } },
                                submitBiometrics: { Task { await model.approveWithBiometrics() } }
                            )
                        }
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Button("Back") { model.backToForm() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(model.isSubmitting)
                Spacer()
                if model.isSubmitting {
                    ProgressView().controlSize(.small)
                }
                Button("Send") { Task { await model.approveWithPassword() } }
                    .brandProminentButton()
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canApproveWithPassword)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private func amountHeader(_ request: TransferRequest, _ row: AssetRow) -> some View {
        HStack(spacing: 12) {
            AssetIconView(asset: row.asset, chain: row.chain, size: 40, showsNetworkBadge: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("You send")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Money.token(request.amount, symbol: row.asset.symbol, maximumFractionDigits: row.asset.decimals, locale: locale))
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()
                    .textSelection(.enabled)
                if let price = row.price?.value {
                    Text("≈ " + Money.fiat(request.amount.fiatValue(unitPrice: price), currency: model.fiat, locale: locale))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Amount plus fee when both are in the same asset, otherwise both listed.
    private func totalText(_ request: TransferRequest, _ row: AssetRow) -> String {
        let amountText = Money.token(request.amount, symbol: row.asset.symbol, maximumFractionDigits: row.asset.decimals, locale: locale)
        guard let fee = model.preparation?.fee else { return amountText }
        if fee.assetID == request.assetID, let sum = request.amount.adding(fee.amount) {
            return Money.token(sum, symbol: row.asset.symbol, maximumFractionDigits: row.asset.decimals, locale: locale)
        }
        return amountText + " + " + (model.feeText ?? "fee")
    }
}

/// A label on the left, its value on the right.
struct ReviewRow<Value: View>: View {
    let label: String
    let value: Value

    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Spacer(minLength: 0)
            value
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
