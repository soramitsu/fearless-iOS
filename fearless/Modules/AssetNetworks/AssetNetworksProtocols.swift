import SSFModels

typealias AssetNetworksModuleCreationResult = (view: AssetNetworksViewInput, input: AssetNetworksModuleInput)

protocol AssetNetworksViewInput: ControllerBackedProtocol, Draggable {
    func didReceive(viewModels: [AssetNetworksTableCellModel])
}

protocol AssetNetworksViewOutput: AnyObject {
    func didLoad(view: AssetNetworksViewInput)
    func didSelect(chainAsset: ChainAsset)
    func didChangeNetworkSwitcher(segmentIndex: Int)
    func didTapSortButton()
}

protocol AssetNetworksInteractorInput: AnyObject {
    func setup(with output: AssetNetworksInteractorOutput)
}

protocol AssetNetworksInteractorOutput: AnyObject {
    func didReceiveChainAssets(_ chainAssets: [ChainAsset])
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceivePricesData(result: Result<[PriceData], Error>)
}

protocol AssetNetworksRouterInput: AnyObject {
    func showDetails(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    )

    func showFilters(
        title: String?,
        filters: [FilterSet],
        moduleOutput: FiltersModuleOutput?,
        from view: ControllerBackedProtocol?
    )
}

protocol AssetNetworksModuleInput: AnyObject {}

protocol AssetNetworksModuleOutput: AnyObject {}
