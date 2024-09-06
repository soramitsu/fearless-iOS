import Foundation
import SSFModels

typealias SelectAssetModuleCreationResult = (view: SelectAssetViewInput, input: SelectAssetModuleInput)

protocol SelectAssetViewInput: SelectionListViewProtocol, LoadableViewProtocol {}

protocol SelectAssetViewOutput: SelectionListPresenterProtocol {
    func didLoad(view: SelectAssetViewInput)
    func willDisappear()
}

protocol SelectAssetInteractorInput: AnyObject {
    func setup(with output: SelectAssetInteractorOutput)
    func update(with chainAssets: [ChainAsset])
}

protocol SelectAssetInteractorOutput: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}

protocol SelectAssetRouterInput: SheetAlertPresentable, ErrorPresentable, PresentDismissable {}

protocol SelectAssetModuleInput: AnyObject {
    func update(with chainAssets: [ChainAsset])
    func runLoading()
}

protocol SelectAssetModuleOutput: AnyObject {
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag: Int?)
}
