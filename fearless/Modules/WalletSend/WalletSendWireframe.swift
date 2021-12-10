import Foundation
import BigInt

final class WalletSendWireframe: WalletSendWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func presentConfirm(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        receiverAddress: String,
        amount: Decimal
    ) {
        guard let controller = WalletSendConfirmViewFactory.createView(
            chain: chain,
            asset: asset,
            receiverAddress: receiverAddress,
            amount: amount
        )?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            controller,
            animated: true
        )
    }
}
