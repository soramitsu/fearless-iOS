import Foundation
import BigInt
import FearlessWalletConnect
import SSFModels
import SSFUtils

/// A dApp request decoded and checked before its confirmation opens. The confirmation
/// shows these values and the signer signs exactly these values: the network, the
/// account the session approved, who receives what, and the most the network can charge.
struct WalletConnectSigningRequest {
    enum Content {
        case ethereumTransaction(WalletConnectEthereumTransactionQuote)
        case ethereumMessage(WalletConnectMessage)
        case ethereumTypedData(WalletConnectTypedData)
        case polkadotTransaction(WalletConnectPolkadotExtrinsic)
        case polkadotMessage(WalletConnectMessage)
    }

    let request: Request
    let method: WalletConnectMethod
    let chain: ChainModel
    let wallet: MetaAccountModel
    /// The account of `wallet` that the session approved for `chain` and that the dApp
    /// asked to sign with. Only its key signs.
    let account: ChainAccountResponse
    let content: Content
    /// The dApp's parameters as text, for the request sheet.
    let preview: String
    /// The dApp's parameters, decoded where possible, for the raw-data view.
    let rawDetails: JSON
}

/// Message bytes exactly as the dApp sent them, before any envelope or prefix is added.
struct WalletConnectMessage: Equatable {
    let bytes: Data

    /// The message as text when it is printable UTF-8.
    var text: String? {
        guard let text = String(data: bytes, encoding: .utf8) else {
            return nil
        }

        let allowedControls = CharacterSet(charactersIn: "\n\r\t")
        let isPrintable = text.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0) || allowedControls.contains($0)
        }
        return isPrintable ? text : nil
    }

    var displayText: String {
        text ?? bytes.toHex(includePrefix: true)
    }

    /// dApps send either `0x`-prefixed hex or plain text.
    init(parameter: String) throws {
        if parameter.hasPrefix("0x") {
            bytes = try Data(hexStringSSF: parameter)
        } else {
            bytes = Data(parameter.utf8)
        }
    }

    init(bytes: Data) {
        self.bytes = bytes
    }
}

/// EIP-712 typed data checked against the request's network.
struct WalletConnectTypedData {
    /// `0x1901 ‖ domainSeparator ‖ hashStruct(message)`; the signer hashes it with Keccak-256.
    let signingInput: Data
    let primaryType: String
    let domainName: String?
    let verifyingContract: Data?
    /// The token spending a permit allows, when the typed data is a known permit.
    let allowance: WalletConnectTokenAllowance?
}

struct WalletConnectTokenAllowance: Equatable {
    let token: Data
    let spender: Data
    let amount: BigUInt
}

/// An EVM transaction with every field fixed before the confirmation opens: the fee shown
/// is the most these gas values can cost, and the signer signs these values only.
struct WalletConnectEthereumTransactionQuote: Equatable {
    enum Fee: Equatable {
        case legacy(gasPrice: BigUInt)
        case eip1559(maxFeePerGas: BigUInt, maxPriorityFeePerGas: BigUInt)
    }

    let chainId: BigUInt
    let from: Data
    let to: Data
    let value: BigUInt
    let data: Data
    let nonce: BigUInt
    let gasLimit: BigUInt
    let fee: Fee
    let tokenCall: WalletConnectTokenCall?

    var maxFee: BigUInt {
        switch fee {
        case let .legacy(gasPrice):
            return gasLimit * gasPrice
        case let .eip1559(maxFeePerGas, _):
            return gasLimit * maxFeePerGas
        }
    }
}

/// An ERC-20 call decoded from a transaction's data.
enum WalletConnectTokenCall: Equatable {
    case transfer(recipient: Data, amount: BigUInt)
    case approve(spender: Data, amount: BigUInt)
}

/// A Substrate transaction from `polkadot_signTransaction`, checked against the chain's
/// genesis hash and current runtime, with its call decoded.
struct WalletConnectPolkadotExtrinsic {
    let payload: TransactionPayload
    let specVersion: UInt32
    let transactionVersion: UInt32
    let nonce: UInt32
    let era: Era
    let tip: BigUInt
    let call: RuntimeCall<JSON>
    let transfer: WalletConnectSubstrateTransfer?
    /// The inclusion fee of this exact extrinsic, without the tip.
    let fee: BigUInt
}

struct WalletConnectSubstrateTransfer: Equatable {
    let recipient: AccountId
    let amount: BigUInt
}

/// Why a dApp request was declined before its confirmation opened.
enum WalletConnectRequestError: Error, Equatable {
    /// The session did not approve the account the dApp asked to sign with.
    case accountNotApproved
    /// The request does not match the network it was sent for.
    case networkMismatch
    /// The transaction was prepared for another runtime version of the chain.
    case runtimeMismatch(chainName: String)
    /// The wallet cannot show exactly what the request would sign.
    case unsupported
    /// The network fee could not be calculated.
    case feeUnavailable

    var rpcError: FearlessWalletConnect.JSONRPCError {
        switch self {
        case .accountNotApproved:
            return FearlessWalletConnect.JSONRPCError(code: 4100, message: "The requested account was not approved for this session")
        case .networkMismatch, .runtimeMismatch:
            return FearlessWalletConnect.JSONRPCError(code: -32602, message: "The request does not match the network")
        case .unsupported:
            return FearlessWalletConnect.JSONRPCError(code: -32602, message: "The request cannot be displayed")
        case .feeUnavailable:
            return FearlessWalletConnect.JSONRPCError(code: -32603, message: "The network fee could not be calculated")
        }
    }
}

extension WalletConnectRequestError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let languages = locale?.rLanguages
        let title = R.string.localizable.walletConnectRequestRejectedTitle(preferredLanguages: languages)
        let message: String
        switch self {
        case .accountNotApproved:
            message = R.string.localizable.walletConnectRequestErrorAccount(preferredLanguages: languages)
        case .networkMismatch:
            message = R.string.localizable.walletConnectRequestErrorNetwork(preferredLanguages: languages)
        case let .runtimeMismatch(chainName):
            message = R.string.localizable.walletConnectRequestErrorRuntime(chainName, preferredLanguages: languages)
        case .unsupported:
            message = R.string.localizable.walletConnectRequestErrorUnsupported(preferredLanguages: languages)
        case .feeUnavailable:
            message = R.string.localizable.walletConnectRequestErrorFee(preferredLanguages: languages)
        }
        return ErrorContent(title: title, message: message)
    }
}
