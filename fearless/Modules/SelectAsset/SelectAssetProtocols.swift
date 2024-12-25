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
    func fetchAccountInfos(with chainAssets: [ChainAsset]) async throws -> [ChainAssetKey: AccountInfo?]
}

protocol SelectAssetInteractorOutput: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
}

protocol SelectAssetRouterInput: SheetAlertPresentable, ErrorPresentable, PresentDismissable {}

protocol SelectAssetModuleInput: AnyObject {
    func update(with chainAssets: [ChainAsset])
    func runLoading()
    func stopLoading()
}

protocol SelectAssetModuleOutput: AnyObject {
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag: Int?)
}
