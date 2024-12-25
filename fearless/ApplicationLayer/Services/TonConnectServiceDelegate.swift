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
    func didDisconnectedApp()
}

extension TonConnectServiceDelegate {
    func suggestConnect(
        manifest _: TonConnectManifest,
        requestPayload _: TonConnectParameters,
        invocationId _: String?,
        delegate _: WalletConnectProposalModuleOutput?
    ) {}
    func send(
        request _: TonConnect.AppRequest,
        invocationId _: String,
        wallet _: MetaAccountModel,
        dapp _: TonDapp,
        delegate _: WalletConnectSessionModuleOutput?
    ) {}
    func send(
        request _: TonConnect.AppRequest,
        walletId _: MetaAccountId,
        app _: TonConnectApp
    ) {}
    func didDisconnectedApp() {}
}
