import Foundation
import WalletConnectSign
import SSFModels

enum ConnectRequestVariant {
    case walletConnect(
        request: Request,
        session: Session?
    )
    case tonJsBridge(
        invocationId: String,
        wallet: MetaAccountModel,
        dapp: TonDapp,
        request: TonConnect.AppRequest,
        delegate: WalletConnectSessionModuleOutput?
    )
    case tonConnect(
        request: TonConnect.AppRequest,
        walletId: SSFModels.MetaAccountId,
        app: TonConnectApp
    )

    var moduleOutput: WalletConnectSessionModuleOutput? {
        switch self {
        case .walletConnect: return nil
        case .tonConnect: return nil
        case let .tonJsBridge(_, _, _, _, delegate): return delegate
        }
    }
}
