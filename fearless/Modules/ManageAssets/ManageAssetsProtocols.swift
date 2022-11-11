import Foundation

protocol ManageAssetsViewProtocol: ControllerBackedProtocol {
    func didReceive(state: ManageAssetsViewState)
    func didReceive(locale: Locale)
}

protocol ManageAssetsPresenterProtocol: AnyObject {
    func setup()
    // swiftlint:disable identifier_name
    func move(from: IndexPath, to: IndexPath)
    func didTapFilterButton()
    func didTapApplyButton()
    func didTapChainSelectButton()
    func searchBarTextDidChange(_ text: String)
}

protocol ManageAssetsInteractorInputProtocol: AnyObject {
    func setup()
    func saveAssetsOrder(assets: [ChainAsset])
    func saveAssetIdsEnabled(_ assetIdsEnabled: [String])
    func markUnused(chain: ChainModel)
    func saveAllChanges()
    func saveFilter(_ options: [FilterOption])
    func saveChainIdForFilter(_ chainId: ChainModel.Id?)
}

protocol ManageAssetsInteractorOutputProtocol: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for key: ChainAssetKey)
    func didReceiveSortOrder(_ sortedKeys: [String]?)
    func didReceiveAssetIdsEnabled(_ assetIdsEnabled: [String]?)
    func didReceiveFilterOptions(_ options: [FilterOption]?)
    func didReceiveAccount(_ account: MetaAccountModel)
    func saveDidComplete()
    func didReceiveWallet(_ wallet: MetaAccountModel)
}

protocol ManageAssetsWireframeProtocol: SheetAlertPresentable, ErrorPresentable, PresentDismissable {
    func presentAccountOptions(
        from view: ControllerBackedProtocol?,
        locale: Locale?,
        options: [MissingAccountOption],
        uniqueChainModel: UniqueChainModel,
        skipBlock: @escaping (ChainModel) -> Void
    )

    func showImport(
        uniqueChainModel: UniqueChainModel,
        from view: ControllerBackedProtocol?
    )

    func showFilters(
        _ filters: [TitleSwitchTableViewCellModel],
        from view: ControllerBackedProtocol?
    )

    func showSelectChain(
        chainModels: [ChainModel]?,
        selectedMetaAccount: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        delegate: ChainSelectionDelegate,
        from view: ControllerBackedProtocol?
    )
}
