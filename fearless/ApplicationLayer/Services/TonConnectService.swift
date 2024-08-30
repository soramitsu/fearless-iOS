import Foundation
import SSFModels

/// Ton Connect has two different ways to establish a connection
/// 1. Ton JS Bridge https://github.com/ton-connect/docs/blob/main/bridge.md#js-bridge
/// 2. HTTP Bridge https://github.com/ton-connect/docs/blob/main/bridge.md#http-bridge
protocol TonConnectService: ApplicationServiceProtocol {

    /// Adding listener for delegate: TonConnectServiceDelegate
    func set(
        listener: TonConnectServiceDelegate
    ) async

    /// Load the Manifest and establish a connection via the Ton Connect service
    func establishConnection(
        with uri: String
    ) async throws

    /// Loading Manifest
    func fetchManifest(
        with url: URL
    ) async throws -> TonConnectManifest

    /// Confirm the connection via the Ton Connect service
    func confirmConnectionRequest(
        wallet: MetaAccountModel,
        tonChainModel: ChainModel,
        params: TonConnectParameters,
        manifest: TonConnectManifest
    ) async throws

    /// Cancels the request from the Ton Connect service
    func cancelRequest(
        appRequest: TonConnect.AppRequest,
        app: TonConnectApp
    ) async throws

    /// Sending a message to the TON blockchain from the JS bridge event
    func approveTonJsBridgeSend(
        wallet: MetaAccountModel,
        parameter: SendTransactionParam
    ) async throws -> String

    /// Sending a message to the TON blockchain
    /// and to the Ton Connect API
    func confirmTonConnectRequest(
        wallet: MetaAccountModel,
        appRequest: TonConnect.AppRequest,
        app: TonConnectApp,
        parameter: SendTransactionParam
    ) async throws

    /// Getting the connected apps from the local repo
    func getConnectedApp(
        for wallet: MetaAccountModel
    ) async throws -> [TonConnectApp]

    /// Saving a new connected app
    /// External or Internal
    func saveConnected(
        app: TonConnectApp
    ) async

    /// Deleting the connected app
    /// External or Internal
    func saveDisconnected(
        app: TonConnectApp
    ) async
}
