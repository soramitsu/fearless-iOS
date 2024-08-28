import Foundation
import SSFModels

protocol TonConnectServiceDelegate: AnyObject {
    func suggestConnect(
        manifest: TonConnectManifest,
        requestPayload: TonConnectParameters,
        invocationId: String?,
        delegate: WalletConnectProposalModuleOutput?
    )
    func send(
        request: TonConnect.AppRequest,
        invocationId: String,
        wallet: MetaAccountModel,
        dapp: TonDapp,
        delegate: WalletConnectSessionModuleOutput?
    )
    func send(
        request: TonConnect.AppRequest,
        walletId: MetaAccountId,
        app: TonConnectApp
    )
    func didDisconnected(app: TonConnectApp)
}

extension TonConnectServiceDelegate {
    func suggestConnect(
        manifest: TonConnectManifest,
        requestPayload: TonConnectParameters,
        invocationId: String?,
        delegate: WalletConnectProposalModuleOutput?
    ) {}
    func send(
        request: TonConnect.AppRequest,
        invocationId: String,
        wallet: MetaAccountModel,
        dapp: TonDapp,
        delegate: WalletConnectSessionModuleOutput?
    ) {}
    func send(
        request: TonConnect.AppRequest,
        walletId: MetaAccountId,
        app: TonConnectApp
    ) {}
    func didDisconnected(
        app: TonConnectApp
    ) {}
}
