import Foundation

struct WalletConnectConfirmationViewModel {
    struct Row: Equatable {
        enum Kind: Equatable {
            case network
            case recipient
            case spender
            case amount
            case fee
            case tip
            case call
            case contract
            case message
            case wallet
            case account
            case app
            case website
            case verification
            /// Something the user must weigh before signing: an undecoded call, extra data, typed data the wallet
            /// does not recognise, a signature for any network, a call whose effect the wallet cannot explain.
            case warning
            /// The 4-byte selector of an EVM call.
            case function
            /// Transaction data shown raw.
            case data
            case from
            /// What a `setApprovalForAll` grants.
            case access
            case deadline
            /// A signed typed-data field the wallet does not specifically understand.
            case field
            /// A Substrate call's arguments, decoded.
            case arguments
        }

        let kind: Kind
        let title: String
        let value: String

        /// Messages, warnings, raw data and decoded calls can be long and are shown in full.
        var isMultiline: Bool {
            [.message, .warning, .data, .field, .arguments, .call].contains(kind)
        }

        var isWarning: Bool {
            kind == .warning
        }
    }

    let symbolViewModel: SymbolViewModel
    let method: String
    /// In display order: the network first, then who receives what and what the network
    /// charges, then the account and the requesting app.
    let rows: [Row]
    let rawData: NSAttributedString
}
