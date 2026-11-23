import DesignSystem
import SwiftUI
import WalletCore

/// After approval: the seal draws each stage as the engine reports it. The
/// figure stays in one place from waiting to the result, and room for the
/// result's lines is reserved so nothing jumps.
struct SendProgressView: View {
    let model: SendModel
    let onClose: () -> Void

    @Environment(\.locale) private var locale

    private struct StageLine: Identifiable {
        let id: SealStage
        let title: String
    }

    private let lines: [StageLine] = [
        StageLine(id: .signed, title: "Signed on this Mac"),
        StageLine(id: .sent, title: "Sent to the network"),
        StageLine(id: .accepted, title: "Included in a block"),
        StageLine(id: .finalized, title: "Final")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                SealView(stage: model.sealStage, failed: model.didFail, uncertain: model.isOutcomeUnknown, size: 176)
                    .padding(.top, 18)
                VStack(spacing: 4) {
                    Text(headline)
                        .font(.brandDisplay(20, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(lines) { line in
                        stageRow(line)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: 320, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Group {
                    if let reason = model.failureReason {
                        InlineMessage(reason, kind: .error, boxed: true)
                    } else if model.isOutcomeUnknown, let reason = model.unknownOutcomeReason {
                        InlineMessage(
                            reason + " It may still go through. Check the explorer or Activity before you send again.",
                            kind: .warning,
                            boxed: true
                        )
                    } else if let hash = model.transactionHash {
                        HStack(spacing: 8) {
                            Text("Transaction").foregroundStyle(.secondary)
                            AddressChip(hash, head: 10, tail: 8)
                            if let url = model.explorerURL {
                                Link(destination: url) {
                                    Label("Explorer", systemImage: "arrow.up.forward.square")
                                }
                                .foregroundStyle(BrandColor.accent)
                                .help("Show the transfer in the block explorer")
                            }
                        }
                        .font(.callout)
                    } else {
                        Text(" ").font(.callout)
                    }
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            Divider()
            HStack {
                if !model.isFinished {
                    Text("You can close this window. The transfer continues and appears in Activity.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if model.didFail || model.isOutcomeUnknown, let hash = model.transactionHash {
                    CopyButtonRow(title: "Copy Hash", value: hash)
                }
                if model.didFail || model.isOutcomeUnknown, let url = model.explorerURL {
                    Link("Open Explorer", destination: url)
                        .foregroundStyle(BrandColor.accent)
                }
                Button(model.isFinished ? "Done" : "Close", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var headline: String {
        if model.didFail { return "The transfer failed" }
        if model.isOutcomeUnknown { return "Sent. Confirmation pending" }
        switch model.sealStage {
        case .idle, .ready: return "Signing the transfer…"
        case .signed: return "Sending to the network…"
        case .sent: return "Waiting for a block…"
        case .accepted: return "In a block. Waiting for finality…"
        case .finalized: return "Transfer complete"
        }
    }

    private var summary: String {
        guard let request = model.submittedRequest, let asset = model.asset else { return " " }
        let amount = Money.token(request.amount, symbol: asset.symbol, maximumFractionDigits: min(8, asset.decimals), locale: locale)
        return "\(amount) to \(AddressFormat.truncated(request.recipient))"
    }

    private func stageRow(_ line: StageLine) -> some View {
        let reached = model.sealStage >= line.id
        let isNext = !reached && !model.isFinished && nextStage == line.id
        return HStack(spacing: 8) {
            ZStack {
                if reached {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(line.id == .finalized ? BrandColor.final : BrandColor.gain)
                } else if isNext {
                    ProgressView().controlSize(.small)
                } else if model.isOutcomeUnknown {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(BrandColor.warning)
                } else if model.didFail {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(BrandColor.failure)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 18, height: 18)
            Text(line.title)
                .font(.callout)
                .foregroundStyle(reached ? Color.primary : Color.secondary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.title)
        .accessibilityValue(reached ? "Done" : (isNext ? "In progress" : (model.isOutcomeUnknown ? "Not confirmed" : (model.didFail ? "Not reached" : "Waiting"))))
    }

    private var nextStage: SealStage? {
        switch model.sealStage {
        case .idle, .ready: return .signed
        case .signed: return .sent
        case .sent: return .accepted
        case .accepted: return .finalized
        case .finalized: return nil
        }
    }
}
