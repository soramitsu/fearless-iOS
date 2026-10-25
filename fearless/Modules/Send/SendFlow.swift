import Foundation
import SSFModels
import SSFQRService

enum SendFlowType {
    case token
    case nft
}

enum SendFlowInitialData {
    case chainAsset(ChainAsset)
    case address(String)
    case soraMainnet(qrInfo: SoraQRInfo)

    init(qrInfoType: QRInfoType) {
        switch qrInfoType {
        case let .sora(soraQRInfo):
            self = .soraMainnet(qrInfo: soraQRInfo)
        case let .cex(cexQRInfo):
            self = .address(cexQRInfo.address)
        }
    }

    var selectableAsset: Bool {
        switch self {
        case .chainAsset, .address:
            return true
        case .soraMainnet:
            return false
        }
    }
}

/// Why Send cannot continue on the selected network. Every reason has calm,
/// truthful copy and a next step inside the app (Receive, Retry or Close), so a
/// routing failure is never a silent dead end.
enum SendUnavailableReason: Equatable {
    case bitcoinSendPaused
    case solanaSendPaused
    case tonWalletSendUnavailable
    case irohaSendUnavailable(networkName: String)
    case assetUnsupported(networkName: String)
    case accountMissing(networkName: String)
    case notPrepared(networkName: String)

    /// Reasons a later step can still hit after Send routed the network, for example a
    /// remote veto that arrives while the confirm screen is open.
    init?(transferError error: Error) {
        if let routingError = error as? UniversalWalletSendRoutingError {
            switch routingError {
            case .bitcoinSendPaused:
                self = .bitcoinSendPaused
            case .solanaSendPaused:
                self = .solanaSendPaused
            case .tonProductionSendDisabled:
                self = .tonWalletSendUnavailable
            case .unsupported, .irohaProductionSendDisabled:
                return nil
            }
            return
        }

        switch error as? TransferServiceError {
        case .bitcoinSendPaused:
            self = .bitcoinSendPaused
        case .solanaSendPaused:
            self = .solanaSendPaused
        case .tonProductionSendDisabled:
            self = .tonWalletSendUnavailable
        default:
            return nil
        }
    }

    /// Maps any error from preparing Send dependencies; unknown failures become a retryable
    /// "couldn't prepare" state instead of a screen that silently never loads a fee.
    init(dependenciesError error: Error, chain: ChainModel) {
        if let reason = SendUnavailableReason(transferError: error) {
            self = reason
            return
        }

        switch error {
        case let routingError as UniversalWalletSendRoutingError:
            if routingError == .irohaProductionSendDisabled {
                self = .irohaSendUnavailable(networkName: chain.name)
            } else {
                self = .assetUnsupported(networkName: chain.name)
            }
        case is ChainAccountFetchingError:
            self = .accountMissing(networkName: chain.name)
        default:
            self = .notPrepared(networkName: chain.name)
        }
    }

    var offersReceive: Bool {
        switch self {
        case .bitcoinSendPaused, .solanaSendPaused, .tonWalletSendUnavailable, .irohaSendUnavailable, .assetUnsupported:
            return true
        case .accountMissing, .notPrepared:
            return false
        }
    }

    var offersRetry: Bool {
        switch self {
        case .notPrepared:
            return true
        case .bitcoinSendPaused, .solanaSendPaused, .tonWalletSendUnavailable, .irohaSendUnavailable,
             .assetUnsupported, .accountMissing:
            return false
        }
    }

    func title(for locale: Locale) -> String {
        let bundle = Self.bundle(for: locale)
        switch self {
        case .bitcoinSendPaused:
            return NSLocalizedString(
                "send.unavailable.bitcoin_paused.title",
                bundle: bundle,
                value: "Bitcoin sending is paused right now",
                comment: ""
            )
        case .solanaSendPaused:
            return NSLocalizedString(
                "send.unavailable.solana_paused.title",
                bundle: bundle,
                value: "Solana sending is paused right now",
                comment: ""
            )
        case .tonWalletSendUnavailable:
            return NSLocalizedString(
                "send.unavailable.ton_wallet.title",
                bundle: bundle,
                value: "Sending TON from this wallet isn't available yet",
                comment: ""
            )
        case let .irohaSendUnavailable(networkName), let .assetUnsupported(networkName):
            let format = NSLocalizedString(
                "send.unavailable.network.title",
                bundle: bundle,
                value: "Sending isn't available on %@",
                comment: "Network name"
            )
            return String(format: format, locale: locale, networkName)
        case let .accountMissing(networkName):
            let format = NSLocalizedString(
                "send.unavailable.account.title",
                bundle: bundle,
                value: "No %@ account in this wallet",
                comment: "Network name"
            )
            return String(format: format, locale: locale, networkName)
        case .notPrepared:
            return NSLocalizedString(
                "send.unavailable.not_prepared.title",
                bundle: bundle,
                value: "Couldn't prepare this transfer",
                comment: ""
            )
        }
    }

    func message(for locale: Locale) -> String {
        let bundle = Self.bundle(for: locale)
        switch self {
        case .bitcoinSendPaused:
            return NSLocalizedString(
                "send.unavailable.bitcoin_paused.message",
                bundle: bundle,
                value: "We're checking Bitcoin sending for this version. Your BTC and balances are " +
                    "unaffected, and you can still receive Bitcoin to this wallet.",
                comment: ""
            )
        case .solanaSendPaused:
            return NSLocalizedString(
                "send.unavailable.solana_paused.message",
                bundle: bundle,
                value: "We're checking Solana sending for this version. Your SOL, tokens and balances " +
                    "are unaffected, and you can still receive on Solana.",
                comment: ""
            )
        case .tonWalletSendUnavailable:
            return NSLocalizedString(
                "send.unavailable.ton_wallet.message",
                bundle: bundle,
                value: "This version can't send TON from this wallet type. Your TON and balances are " +
                    "unaffected, and you can still receive TON to this wallet.",
                comment: ""
            )
        case .irohaSendUnavailable:
            return NSLocalizedString(
                "send.unavailable.iroha.message",
                bundle: bundle,
                value: "This version can't send on this network yet. Your balance is unaffected, and " +
                    "you can still receive here.",
                comment: ""
            )
        case .assetUnsupported:
            return NSLocalizedString(
                "send.unavailable.asset.message",
                bundle: bundle,
                value: "This version can't send this asset on this network. Your balance is unaffected, " +
                    "and you can still receive it.",
                comment: ""
            )
        case .accountMissing:
            return NSLocalizedString(
                "send.unavailable.account.message",
                bundle: bundle,
                value: "This wallet has no account on this network, so there is nothing to send from it. " +
                    "Choose another network or wallet.",
                comment: ""
            )
        case let .notPrepared(networkName):
            let format = NSLocalizedString(
                "send.unavailable.not_prepared.message",
                bundle: bundle,
                value: "Fearless couldn't reach %@ to prepare this transfer. Nothing was sent. Check " +
                    "your connection and try again.",
                comment: "Network name"
            )
            return String(format: format, locale: locale, networkName)
        }
    }

    private static func bundle(for locale: Locale) -> Bundle {
        Bundle.localizationBundle(for: locale)
    }
}
