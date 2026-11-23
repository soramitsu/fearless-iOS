import Foundation
import WalletCore

/// Turns any error into one sentence for the user.
enum ErrorText {
    static func message(for error: Error) -> String {
        if let wallet = error as? WalletError {
            return wallet.errorDescription ?? "Something went wrong."
        }
        if error is CancellationError {
            return "The operation was cancelled."
        }
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return text.isEmpty ? "Something went wrong." : text
    }
}

/// Loading state of a pane that fetches its content.
enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)

    var isLoading: Bool { self == .loading }

    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
