protocol AssetSelectionWireframeProtocol: AlertPresentable, ErrorPresentable {
    func complete(on view: ChainSelectionViewProtocol, selecting chainAsset: ChainAsset)
}

protocol AssetSelectionDelegate: AnyObject {
    func assetSelection(view: ChainSelectionViewProtocol, didCompleteWith chainAsset: ChainAsset)
}

typealias AssetSelectionFilter = (ChainModel, AssetModel) -> Bool
