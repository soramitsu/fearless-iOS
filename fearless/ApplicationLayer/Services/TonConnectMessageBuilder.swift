import Foundation
import SoraKeystore
import SSFModels
import WebKit
import TonSwift

protocol TonConnectMessageBuilder {
    /// WKWebViewConfiguration with the js injection script
    func getConfiguration(
        userContentController: WKUserContentController
    ) -> WKWebViewConfiguration

    /// Building the message to reconnect the dApp
    /// Reconnecting if already connected and the dApp is in local store
    func getConnectEventSuccess(
        wallet: MetaAccountModel
    ) throws -> String

    /// Parsing the DappFunctionInvokeMessage from the body
    func getDappFunctionInvokeMessage(
        from body: Any
    ) throws -> DappFunctionInvokeMessage

    /// Parsing the TonConnectRequestPayload from the message
    func getTonConnectRequestPayload(
        from message: DappFunctionInvokeMessage
    ) throws -> TonConnectRequestPayload

    /// Parsing the AppRequest to present it to the user for approval or rejection
    /// Proposal for the user based on the JS Bridge connection type
    func getTonConnectAppRequest(
        from message: DappFunctionInvokeMessage
    ) throws -> TonConnect.AppRequest

    /// Parsing the ConnectEventSuccess
    /// ConnectEventSuccess can be send via JS Bridge and HTTP
    /// Sends if the connection has been approved by the user
    func getConnectEventSuccessResponse(
        requestPayloadItems: [TonConnectRequestPayload.Item],
        wallet: MetaAccountModel,
        manifest: TonConnectManifest,
        tonChainModel: ChainModel
    ) throws -> TonConnect.ConnectEventSuccess

    /// Encrypt the ConnectEventSuccess using TonConnectSessionCrypto
    /// Used for sending the message via HTTP connection
    func encryptSuccessResponse(
        successResponse: TonConnect.ConnectEventSuccess,
        clientId: String,
        sessionCrypto: TonConnectSessionCrypto
    ) throws -> String

    /// Build the SendTransactionResponseError error message
    func buildSendTransactionResponseError(
        sessionCrypto: TonConnectSessionCrypto,
        errorCode: TonConnect.SendTransactionResponseError.ErrorCode,
        id: String,
        clientId: String
    ) throws -> String

    /// Preparing the message for the Ton Connect API from boc
    func buildSendTransactionResponseSuccess(
        sessionCrypto: TonConnectSessionCrypto,
        boc: String,
        id: String,
        clientId: String
    ) throws -> String

    /// Encode to String any Event
    func getString(from event: Encodable) throws -> String
}
