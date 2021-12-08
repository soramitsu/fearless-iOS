import Foundation
import UIKit

final class ChainAccountWireframe: ChainAccountWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func presentSendFlow(
        from view: ControllerBackedProtocol?,
        asset: AssetModel,
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel
    ) {
        let searchView = SearchPeopleViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedMetaAccount: selectedMetaAccount
        )

        guard let controller = searchView?.controller else {
            return
        }

//        let navigationController = UINavigationController(rootViewController: controller)

        view?.controller.present(controller, animated: true)
    }
}
