import Foundation
import SSFModels

protocol TonConnectService: ApplicationServiceProtocol {
    func set(
        listener: TonConnectServiceDelegate
    ) async

    func establishConnection(
        with uri: String
    ) async throws

    func fetchManifest(
        with url: URL
    ) async throws -> TonConnectManifest

    func confirmConnectionRequest(
        wallet: MetaAccountModel,
        tonChainModel: ChainModel,
        params: TonConnectParameters,
        manifest: TonConnectManifest
    ) async throws

    func cancelRequest(
        appRequest: TonConnect.AppRequest,
        app: TonConnectApp
    ) async throws

    func approveTonConnect(
        wallet: MetaAccountModel,
        parameter: SendTransactionParam
    ) async throws -> String

    func confirmRequest(
        wallet: MetaAccountModel,
        appRequest: TonConnect.AppRequest,
        app: TonConnectApp,
        parameter: SendTransactionParam
    ) async throws

    func getConnectedApp(
        for wallet: MetaAccountModel
    ) async throws -> [TonConnectApp]

    func saveConnected(
        app: TonConnectApp
    ) async

    func saveDisconnected(
        app: TonConnectApp
    ) async
}
