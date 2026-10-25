import Foundation

/// Checks a Solana recipient against the chain before anything is signed, so a transfer never
/// sends funds where nobody can spend them.
///
/// - A token transfer creates the recipient's associated token account for whatever address
///   it is given. If that address is itself a token account (an associated token account is
///   off the ed25519 curve; an explicitly created one may be on it) or a program, nobody holds
///   a key for the new account and the tokens are lost. Token transfers therefore need an
///   on-curve address that no token program owns and that is not a program.
/// - SOL sent to a token account becomes part of that account's rent, and SOL sent to a
///   program is locked. Native transfers refuse both, but accept other off-curve addresses:
///   multisig vaults are system accounts at program-derived addresses.
enum SolanaRecipientValidator {
    enum Purpose: Equatable {
        case nativeTransfer
        case tokenTransfer
    }

    static let tokenProgramOwners: Set<String> = [
        SolanaTransferTransactionBuilder.splTokenProgramAddress,
        SolanaTransferTransactionBuilder.token2022ProgramAddress
    ]

    /// The size of an SPL token account, whose rent a transfer pays when it opens one.
    static let tokenAccountDataLength = 165

    /// Returns the normalized address and its account as the chain has it (nil if it does not
    /// exist yet), or throws the reason the address cannot receive this transfer.
    static func validateRecipientAddress(
        _ recipient: String,
        purpose: Purpose,
        rpcClient: SolanaRpcClientProtocol,
        rpcURL: String?
    ) async throws -> SolanaValidatedRecipient {
        let normalized: String
        do {
            normalized = try SolanaTransferTransactionBuilder.normalizeRecipientAddress(recipient)
        } catch {
            throw SolanaTransferRefusal.invalidRecipient
        }

        if purpose == .tokenTransfer, !SolanaTransferTransactionBuilder.isOnEd25519Curve(address: normalized) {
            throw SolanaTransferRefusal.recipientNotWallet
        }

        let account = try await rpcClient.accountInfo(address: normalized, commitment: .confirmed, rpcURL: rpcURL)
        if let account {
            if tokenProgramOwners.contains(account.owner) {
                throw SolanaTransferRefusal.recipientIsTokenAccount
            }
            if account.executable {
                throw SolanaTransferRefusal.recipientIsProgram
            }
        }

        return SolanaValidatedRecipient(address: normalized, account: account)
    }
}

struct SolanaValidatedRecipient: Equatable {
    let address: String
    /// nil when the account does not exist yet.
    let account: SolanaAccountInfo?
}

/// A Solana transfer the wallet refused before signing, with copy that says what to do next.
/// Nothing left the wallet for any of these.
enum SolanaTransferRefusal: Error, Equatable {
    case invalidRecipient
    /// Off curve: an associated token account or another program-derived address.
    case recipientNotWallet
    case recipientIsTokenAccount
    case recipientIsProgram
    /// A new Solana account must start with at least the rent-exempt minimum.
    case amountBelowNewAccountMinimum(minimumLamports: Int64)
    /// The sender would keep more than zero but less than the rent-exempt minimum, which the
    /// network refuses.
    case remainderBelowAccountMinimum(minimumLamports: Int64)
    /// Not enough SOL for the amount (native) plus the network fee and any account the
    /// transfer opens.
    case insufficientSol
    case insufficientTokenBalance
    /// The wallet holds the amount only across several token accounts of the mint, and one
    /// transfer moves tokens out of one account.
    case tokenBalanceSplit
    /// The token is held under a program this version cannot send yet (Token-2022).
    case unsupportedTokenProgram
}

extension SolanaTransferRefusal: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let locale = locale ?? .current
        let bundle = Self.bundle(for: locale)

        switch self {
        case .invalidRecipient:
            return ErrorContent(
                title: NSLocalizedString(
                    "solana.transfer.recipient_invalid.title",
                    bundle: bundle,
                    value: "This isn't a Solana address",
                    comment: ""
                ),
                message: NSLocalizedString(
                    "solana.transfer.recipient_invalid.message",
                    bundle: bundle,
                    value: "Check the address and try again. Nothing was sent.",
                    comment: ""
                )
            )
        case .recipientNotWallet, .recipientIsTokenAccount:
            return ErrorContent(
                title: NSLocalizedString(
                    "solana.transfer.recipient_token_account.title",
                    bundle: bundle,
                    value: "This is a token account, not a wallet",
                    comment: ""
                ),
                message: NSLocalizedString(
                    "solana.transfer.recipient_token_account.message",
                    bundle: bundle,
                    value: "This looks like a token account, not a wallet address. Funds sent here could " +
                        "be lost. Ask the recipient for their Solana wallet address. Nothing was sent.",
                    comment: ""
                )
            )
        case .recipientIsProgram:
            return ErrorContent(
                title: NSLocalizedString(
                    "solana.transfer.recipient_program.title",
                    bundle: bundle,
                    value: "This is a program, not a wallet",
                    comment: ""
                ),
                message: NSLocalizedString(
                    "solana.transfer.recipient_program.message",
                    bundle: bundle,
                    value: "This address belongs to a Solana program. Funds sent here would be locked. " +
                        "Ask the recipient for their Solana wallet address. Nothing was sent.",
                    comment: ""
                )
            )
        case let .amountBelowNewAccountMinimum(minimumLamports):
            let format = NSLocalizedString(
                "solana.transfer.below_new_account_minimum.message",
                bundle: bundle,
                value: "This address has no SOL yet. Solana requires at least %@ SOL to open it. " +
                    "Send at least that much. Nothing was sent.",
                comment: "Minimum SOL amount"
            )
            return ErrorContent(
                title: NSLocalizedString(
                    "solana.transfer.below_new_account_minimum.title",
                    bundle: bundle,
                    value: "Amount too small for a new account",
                    comment: ""
                ),
                message: String(format: format, locale: locale, Self.sol(minimumLamports, locale: locale))
            )
        case let .remainderBelowAccountMinimum(minimumLamports):
            let format = NSLocalizedString(
                "solana.transfer.remainder_below_minimum.message",
                bundle: bundle,
                value: "Solana requires a wallet to keep either nothing or at least %@ SOL. Send " +
                    "everything (Max) or leave at least that much. Nothing was sent.",
                comment: "Minimum SOL amount"
            )
            return ErrorContent(
                title: NSLocalizedString(
                    "solana.transfer.remainder_below_minimum.title",
                    bundle: bundle,
                    value: "Leave more SOL or send it all",
                    comment: ""
                ),
                message: String(format: format, locale: locale, Self.sol(minimumLamports, locale: locale))
            )
        case .insufficientSol:
            return ErrorContent(
                title: NSLocalizedString(
                    "solana.transfer.insufficient_sol.title",
                    bundle: bundle,
                    value: "Not enough SOL",
                    comment: ""
                ),
                message: NSLocalizedString(
                    "solana.transfer.insufficient_sol.message",
                    bundle: bundle,
                    value: "This wallet doesn't hold enough SOL for the amount and the network fee, plus, " +
                        "for a first-time token holder, the account Solana opens for them. Add SOL or " +
                        "lower the amount. Nothing was sent.",
                    comment: ""
                )
            )
        case .insufficientTokenBalance:
            return ErrorContent(
                title: NSLocalizedString(
                    "solana.transfer.insufficient_token.title",
                    bundle: bundle,
                    value: "Not enough tokens",
                    comment: ""
                ),
                message: NSLocalizedString(
                    "solana.transfer.insufficient_token.message",
                    bundle: bundle,
                    value: "This wallet doesn't hold that many of this token in one account. Lower the " +
                        "amount and try again. Nothing was sent.",
                    comment: ""
                )
            )
        case .tokenBalanceSplit:
            return ErrorContent(
                title: NSLocalizedString(
                    "solana.transfer.token_balance_split.title",
                    bundle: bundle,
                    value: "Balance held in several token accounts",
                    comment: ""
                ),
                message: NSLocalizedString(
                    "solana.transfer.token_balance_split.message",
                    bundle: bundle,
                    value: "Your balance of this token is split across several token accounts, and none " +
                        "of them holds this amount alone. Send a smaller amount first, then send the rest. " +
                        "Nothing was sent.",
                    comment: ""
                )
            )
        case .unsupportedTokenProgram:
            return ErrorContent(
                title: NSLocalizedString(
                    "solana.transfer.token_program_unsupported.title",
                    bundle: bundle,
                    value: "This token can't be sent yet",
                    comment: ""
                ),
                message: NSLocalizedString(
                    "solana.transfer.token_program_unsupported.message",
                    bundle: bundle,
                    value: "This version can send SOL and standard SPL tokens. This token uses Token-2022, " +
                        "which isn't supported yet. It stays in your wallet, and you can still receive it.",
                    comment: ""
                )
            )
        }
    }

    static func sol(_ lamports: Int64, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 9
        let value = Decimal(lamports) / Decimal(1_000_000_000)
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    private static func bundle(for locale: Locale) -> Bundle {
        Bundle.localizationBundle(for: locale)
    }
}
