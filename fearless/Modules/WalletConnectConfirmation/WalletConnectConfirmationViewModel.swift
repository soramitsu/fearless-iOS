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
        }

        let kind: Kind
        let title: String
        let value: String

        /// Messages and decoded calls can be long and are shown in full.
        var isMultiline: Bool {
            kind == .message
        }
    }

    let symbolViewModel: SymbolViewModel
    let method: String
    /// In display order: the network first, then who receives what and what the network
    /// charges, then the account and the requesting app.
    let rows: [Row]
    let rawData: NSAttributedString
}
