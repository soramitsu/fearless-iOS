import Foundation

enum TonConnectSendDessision {
    case sent(
        invocationId: String,
        response: TonConnect.SendTransactionResponse
    )
    case error(
        invocationId: String,
        error: TonConnect.SendTransactionResponseError.ErrorCode
    )
    case declined(
        invocationId: String
    )
}
