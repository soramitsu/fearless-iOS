import Foundation
import SSFModels

typealias SelectAssetModuleCreationResult = (view: SelectAssetViewInput, input: SelectAssetModuleInput)

protocol SelectAssetViewInput: SelectionListViewProtocol {}

protocol SelectAssetViewOutput: SelectionListPresenterProtocol {
    func didLoad(view: SelectAssetViewInput)
    func willDisappear()
}

protocol SelectAssetInteractorInput: AnyObject {
    func setup(with output: SelectAssetInteractorOutput)
}

protocol SelectAssetInteractorOutput: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}

protocol SelectAssetRouterInput: SheetAlertPresentable, ErrorPresentable, PresentDismissable {}

protocol SelectAssetModuleInput: AnyObject {}

protocol SelectAssetModuleOutput: AnyObject {
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag: Int?)
}
