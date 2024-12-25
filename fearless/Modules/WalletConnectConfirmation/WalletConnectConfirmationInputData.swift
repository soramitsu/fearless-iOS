import Foundation
import SSFModels
import WalletConnectSign

struct WalletConnectConfirmationInputData {
    enum Variant {
        case walletConnect(
            resuest: Request,
            session: Session,
            method: WalletConnectMethod
        )
        case tonJsBridge(
            invocationId: String,
            dapp: TonDapp,
            request: TonConnect.AppRequest,
            moduleOutput: WalletConnectSessionModuleOutput?
        )
        case tonConnect(
            request: TonConnect.AppRequest,
            app: TonConnectApp
        )
    }

    let wallet: MetaAccountModel
    let chain: ChainModel
    let variant: Variant
    let payload: WalletConnectPayload

    var moduleOutput: WalletConnectSessionModuleOutput? {
        switch variant {
        case .walletConnect, .tonConnect: return nil
        case let .tonJsBridge(_, _, _, moduleOutput): return moduleOutput
        }
    }
}
