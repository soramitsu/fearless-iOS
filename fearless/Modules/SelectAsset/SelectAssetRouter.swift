import Foundation

protocol SelectAssetDelegate: AnyObject {
    func assetSelection(view: SelectAssetViewInput, didCompleteWith asset: AssetModel?)
}

final class SelectAssetRouter: SelectAssetRouterInput {
    private weak var delegate: SelectAssetDelegate?

    init(delegate: SelectAssetDelegate?) {
        self.delegate = delegate
    }

    func complete(on view: SelectAssetViewInput, selecting asset: AssetModel?) {
        view.controller.dismiss(animated: true)
        delegate?.assetSelection(view: view, didCompleteWith: asset)
    }
}
