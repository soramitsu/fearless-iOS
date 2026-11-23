import DesignSystem
import SwiftUI
import WalletCore

/// The send flow as a sheet over the main window: form, review, progress.
struct SendSheet: View {
    @Bindable var model: SendModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                switch model.stage {
                case .form: SendFormView(model: model, onClose: onClose)
                case .review: SendReviewView(model: model)
                case .progress: SendProgressView(model: model, onClose: onClose)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 540, height: 640)
        .interactiveDismissDisabled(model.stage != .form)
        .task { await model.prepareNow() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            WalletAvatar(wallet: model.wallet, size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("From \(model.wallet.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StepDots(current: stepIndex, count: 3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var title: String {
        switch model.stage {
        case .form: return "Send"
        case .review: return "Review Transfer"
        case .progress: return "Transfer"
        }
    }

    private var stepIndex: Int {
        switch model.stage {
        case .form: return 0
        case .review: return 1
        case .progress: return 2
        }
    }
}

/// Small dots that show which step of a short flow is current.
struct StepDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? BrandColor.accent : Color.primary.opacity(index < current ? 0.35 : 0.15))
                    .frame(width: index == current ? 16 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

// MARK: - Form

struct SendFormView: View {
    @Bindable var model: SendModel
    let onClose: () -> Void

    private enum Field { case recipient, amount }
    @FocusState private var focus: Field?
    @State private var showKeepAliveInfo = false
    @Environment(\.balancesHidden) private var balancesHidden

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    assetSection
                    recipientSection
                    amountSection
                    if model.isSubstrate { keepAliveSection }
                    feeSection
                    ForEach(model.generalMessages) { message in
                        InlineMessage(message.text, kind: .error, boxed: true) {
                            if message.isRetryable {
                                Button("Try Again") { Task { await model.retry() } }
                                    .controlSize(.small)
                            }
                        }
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Continue") { Task { await model.review() } }
                    .brandProminentButton()
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.recipientText.isEmpty || model.amountText.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .onAppear { if focus == nil { focus = .recipient } }
    }

    // MARK: Asset

    private var assetSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("Asset")
            HStack(spacing: 10) {
                if let row = model.selectedRow {
                    AssetIconView(asset: row.asset, chain: row.chain, size: 30, showsNetworkBadge: true)
                }
                Picker("Asset", selection: Binding(
                    get: { model.assetID },
                    set: { if let id = $0 { model.selectAsset(id) } }
                )) {
                    ForEach(model.rowsByChain, id: \.chain.id) { group in
                        Section(group.chain.name) {
                            ForEach(group.rows) { row in
                                Text(pickerTitle(row)).tag(AssetID?.some(row.id))
                            }
                        }
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Asset")
            }
            if let row = model.selectedRow, let transferable = row.transferable {
                HStack(spacing: 4) {
                    Text("Available:")
                    AmountText(transferable, symbol: row.asset.symbol, maximumFractionDigits: min(8, row.asset.decimals))
                    if let locked = row.locked, !locked.isZero {
                        Text("·")
                        AmountText(locked, symbol: nil, maximumFractionDigits: 4)
                        Text("locked")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func pickerTitle(_ row: AssetRow) -> String {
        guard let transferable = row.transferable, !balancesHidden else { return "\(row.asset.symbol) on \(row.chain.name)" }
        return "\(row.asset.symbol) — \(transferable.formatted(maximumFractionDigits: 4)) available"
    }

    // MARK: Recipient

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("To")
            HStack(spacing: 6) {
                TextField(model.chain.map { "\($0.name) address" } ?? "Address", text: $model.recipientText, axis: .vertical)
                    .lineLimit(1...2)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .focused($focus, equals: .recipient)
                    .accessibilityLabel("Recipient address")
                    .dropDestination(for: String.self) { items, _ in
                        guard let text = items.first else { return false }
                        model.setRecipient(text)
                        return true
                    }
                recipientStatus
                Button {
                    if let text = Clipboard.shared.string() { model.setRecipient(text) }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .help("Paste the address from the clipboard")
                .accessibilityLabel("Paste address")
            }
            if let message = model.recipientMessage {
                InlineMessage(message.text, kind: model.isRecipientWrongNetwork ? .warning : .error, boxed: model.isRecipientWrongNetwork)
            }
        }
    }

    @ViewBuilder private var recipientStatus: some View {
        if model.isValidatingRecipient {
            ProgressView().controlSize(.small).accessibilityLabel("Checking address")
        } else if model.isRecipientValid {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(BrandColor.gain)
                .help("Valid \(model.chain?.name ?? "") address")
                .accessibilityLabel("Valid address")
        }
    }

    // MARK: Amount

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("Amount")
            HStack(spacing: 8) {
                TextField("0", text: $model.amountText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 20, weight: .medium).monospacedDigit())
                    .focused($focus, equals: .amount)
                    .onSubmit { Task { await model.review() } }
                    .accessibilityLabel("Amount in \(unitName)")
                Button {
                    model.toggleAmountUnit()
                } label: {
                    HStack(spacing: 4) {
                        Text(unitName).fontWeight(.medium)
                        Image(systemName: "arrow.up.arrow.down").font(.caption)
                    }
                    .frame(minWidth: 56)
                }
                .disabled(!model.canUseFiat)
                .help(model.canUseFiat ? "Switch between \(model.asset?.symbol ?? "the asset") and \(model.fiat.code.uppercased())" : "This asset has no price")
                .accessibilityLabel("Amount unit: \(unitName). Switch unit")
                Button("Max") { Task { await model.setMax() } }
                    .help("Send everything that can be sent after the fee")
            }
            .controlSize(.large)
            HStack {
                if let message = model.amountMessage {
                    InlineMessage(message.text, kind: .error)
                } else if let converted = model.convertedAmountText {
                    Text(converted)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text(" ").font(.callout)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var unitName: String {
        model.amountUnit == .fiat ? model.fiat.code.uppercased() : (model.asset?.symbol ?? "")
    }

    // MARK: Keep-alive and fee

    private var keepAliveSection: some View {
        HStack(spacing: 6) {
            Toggle("Keep my account open", isOn: $model.keepAlive)
                .toggleStyle(.checkbox)
            Button {
                showKeepAliveInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .help("What does this mean?")
            .accessibilityLabel("About keeping the account open")
            .popover(isPresented: $showKeepAliveInfo, arrowEdge: .bottom) {
                Text(model.keepAliveExplanation)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(width: 300)
            }
            Spacer()
        }
    }

    private var feeSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Network fee")
                .foregroundStyle(.secondary)
            Spacer()
            if model.isPreparing, model.feeText == nil {
                CometLoader(size: 18)
                Text("Estimating…").foregroundStyle(.secondary)
            } else if let fee = model.feeText {
                Text(fee).monospacedDigit()
                if let fiat = model.feeFiatText {
                    Text("(\(fiat))").foregroundStyle(.secondary).monospacedDigit()
                }
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
        .font(.callout)
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A small heading above a form field.
struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .accessibilityHidden(true)
    }
}
