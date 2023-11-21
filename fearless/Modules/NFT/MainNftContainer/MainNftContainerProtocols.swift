import SSFModels

typealias MainNftContainerModuleCreationResult = (view: MainNftContainerViewInput, input: MainNftContainerModuleInput)

protocol MainNftContainerViewInput: ControllerBackedProtocol {
    func didReceive(viewModels: [NftListCellModel]?)
    func didReceive(appearance: NftCollectionAppearance)
}

protocol MainNftContainerViewOutput: AnyObject {
    func didLoad(view: MainNftContainerViewInput)
    func didSelect(collection: NFTCollection)
    func didPullToRefresh()
    func viewAppeared()
    func didTapFilterButton()
    func didTapCollectionButton()
    func didTapTableButton()
}

protocol MainNftContainerInteractorInput: AnyObject {
    func initialSetup()
    func setup(with output: MainNftContainerInteractorOutput)
    func fetchData()
    func didSelect(chain: ChainModel?)
    func applyFilters(_ filters: [FilterSet])
}

protocol MainNftContainerInteractorOutput: AnyObject {
    func didReceive(collections: [NFTCollection])
}

protocol MainNftContainerRouterInput: AnyObject {
    func showCollection(
        _ collection: NFTCollection,
        wallet: MetaAccountModel,
        address: String,
        from view: ControllerBackedProtocol?
    )

    func presentFilters(
        with filters: [FilterSet],
        from view: ControllerBackedProtocol?,
        moduleOutput: NftFiltersModuleOutput?
    )
}

protocol MainNftContainerModuleInput: AnyObject {
    func didSelect(chain: ChainModel?)
}

protocol MainNftContainerModuleOutput: AnyObject {}
