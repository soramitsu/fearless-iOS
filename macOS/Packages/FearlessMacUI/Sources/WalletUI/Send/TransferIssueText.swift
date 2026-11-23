import DesignSystem
import Foundation
import WalletCore

/// Where an issue is shown in the send form.
enum SendField: Equatable {
    case recipient
    case amount
    case general
}

/// One transfer issue as the user reads it.
struct IssueMessage: Identifiable, Equatable {
    let field: SendField
    let text: String
    /// True when trying again may help (network problems).
    var isRetryable = false

    var id: String { text }
}

/// Maps the engine's transfer issues to plain sentences.
enum TransferIssueText {
    static func message(for issue: TransferIssue, asset: Asset, feeSymbol: String, chain: Chain, locale: Locale = .current) -> IssueMessage {
        func amount(_ value: TokenAmount, _ symbol: String) -> String {
            Money.token(value, symbol: symbol, maximumFractionDigits: 6, locale: locale)
        }
        switch issue {
        case .watchOnlyWallet:
            return IssueMessage(field: .general, text: "This is a watch-only wallet. It has no keys, so it cannot send.")
        case .unsupportedAsset:
            return IssueMessage(field: .general, text: "Sending \(asset.symbol) on \(chain.name) is not supported yet.")
        case .invalidRecipient(let reason):
            return IssueMessage(field: .recipient, text: reason.isEmpty ? "Enter a valid \(chain.name) address." : reason)
        case .recipientIsSender:
            return IssueMessage(field: .recipient, text: "This is your own address on \(chain.name). Choose another recipient.")
        case .amountIsZero:
            return IssueMessage(field: .amount, text: "Enter an amount greater than zero.")
        case .insufficientBalance(let available):
            return IssueMessage(field: .amount, text: "You can send at most \(amount(available, asset.symbol)) before fees.")
        case .insufficientBalanceForFee(let fee):
            return IssueMessage(field: .amount, text: "Not enough \(feeSymbol) for the network fee of \(amount(fee, feeSymbol)).")
        case .belowExistentialDeposit(let minimum):
            return IssueMessage(field: .amount, text: "A new \(chain.name) account must receive at least \(amount(minimum, asset.symbol)). Send more, or the funds would be lost.")
        case .wouldReapSender(let minimumRemaining):
            return IssueMessage(field: .amount, text: "This would leave less than \(amount(minimumRemaining, asset.symbol)), the minimum \(chain.name) keeps an account open with. Send less, or turn off \u{201C}Keep my account open\u{201D}.")
        case .network(let reason):
            return IssueMessage(field: .general, text: reason.isEmpty ? "The network did not answer. Try again." : reason, isRetryable: true)
        }
    }
}
