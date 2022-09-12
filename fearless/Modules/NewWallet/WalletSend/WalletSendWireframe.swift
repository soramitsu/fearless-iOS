import Foundation
import BigInt

final class WalletSendWireframe: WalletSendWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func presentConfirm(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        receiverAddress: String,
        amount: Decimal,
        tip: Decimal?,
        transferFinishBlock: WalletTransferFinishBlock?
    ) {
        guard let controller = WalletSendConfirmViewFactory.createView(
            chainAsset: chainAsset,
            receiverAddress: receiverAddress,
            amount: amount,
            tip: tip,
            transferFinishBlock: transferFinishBlock
        )?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            controller,
            animated: true
        )
    }
}
