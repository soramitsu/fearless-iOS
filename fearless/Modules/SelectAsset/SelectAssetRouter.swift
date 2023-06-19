import Foundation
import SSFModels

final class SelectAssetRouter: SelectAssetRouterInput {
    func complete(on view: SelectAssetViewInput, selecting _: AssetModel?) {
        view.controller.dismiss(animated: true)
    }
}
