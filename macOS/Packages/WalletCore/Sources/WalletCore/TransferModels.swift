import Foundation

public struct TransferRequest: Hashable, Sendable {
    public var walletID: WalletID
    public var assetID: AssetID
    public var recipient: String
    public var amount: TokenAmount
    /// Substrate: refuse to drop the sender below the existential deposit
    /// (`transfer_keep_alive`). Ignored on EVM chains.
    public var keepAlive: Bool

    public init(walletID: WalletID, assetID: AssetID, recipient: String, amount: TokenAmount, keepAlive: Bool = true) {
        self.walletID = walletID
        self.assetID = assetID
        self.recipient = recipient
        self.amount = amount
        self.keepAlive = keepAlive
    }
}

public enum RecipientValidation: Hashable, Sendable {
    /// Valid; `normalized` is the address formatted for the chain.
    case valid(normalized: String)
    case empty
    case invalid(reason: String)
    /// A valid address of another network (e.g. a Kusama address on Polkadot).
    case wrongNetwork(reason: String)
}

public struct FeeEstimate: Hashable, Sendable {
    public var assetID: AssetID
    public var amount: TokenAmount

    public init(assetID: AssetID, amount: TokenAmount) {
        self.assetID = assetID
        self.amount = amount
    }
}

public enum TransferIssue: Hashable, Sendable {
    case watchOnlyWallet
    case unsupportedAsset
    case invalidRecipient(String)
    case recipientIsSender
    case amountIsZero
    case insufficientBalance(available: TokenAmount)
    case insufficientBalanceForFee(fee: TokenAmount)
    /// A new account on a Substrate chain must receive at least this much.
    case belowExistentialDeposit(minimum: TokenAmount)
    /// The send would leave the sender below the existential deposit.
    case wouldReapSender(minimumRemaining: TokenAmount)
    case network(String)

    /// Blocking issues stop the Send button; others are warnings.
    public var isBlocking: Bool { true }
}

public struct TransferPreparation: Hashable, Sendable {
    public var request: TransferRequest
    public var fee: FeeEstimate?
    public var issues: [TransferIssue]
    /// Largest amount that can be sent after the fee and existential deposit.
    public var maxSendable: TokenAmount?

    public init(request: TransferRequest, fee: FeeEstimate?, issues: [TransferIssue], maxSendable: TokenAmount?) {
        self.request = request
        self.fee = fee
        self.issues = issues
        self.maxSendable = maxSendable
    }

    public var canSubmit: Bool { fee != nil && !issues.contains(where: \.isBlocking) }
}

/// Stages of a submitted transfer, in order. The stream ends after
/// `.finalized` or `.failed`.
public enum TransferProgress: Hashable, Sendable {
    case signed
    case broadcast(hash: String, explorerURL: URL?)
    /// Included in a block (Substrate in-block / EVM receipt).
    case included(blockHash: String?)
    case finalized
    case failed(reason: String)
}
