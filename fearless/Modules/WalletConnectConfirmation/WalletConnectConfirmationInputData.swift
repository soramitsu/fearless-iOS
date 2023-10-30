import Foundation
import SSFModels
import WalletConnectSign

struct WalletConnectConfirmationInputData {
    let wallet: MetaAccountModel
    let chain: ChainModel
    let resuest: Request
    let session: Session
    let method: WalletConnectMethod
    let payload: WalletConnectPayload
}
