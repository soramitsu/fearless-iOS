import SSFModels

protocol AssetSelectionWireframeProtocol: SheetAlertPresentable, ErrorPresentable {
    func complete(
        on view: ChainSelectionViewProtocol,
        selecting chainAsset: ChainAsset,
        context: Any?
    )
}

protocol AssetSelectionDelegate: AnyObject {
    func assetSelection(
        view: ChainSelectionViewProtocol,
        didCompleteWith chainAsset: ChainAsset,
        context: Any?
    )
}

typealias AssetSelectionFilter = (AssetModel) -> Bool
