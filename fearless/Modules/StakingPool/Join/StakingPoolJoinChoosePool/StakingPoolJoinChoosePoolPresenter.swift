import Foundation
import SoraFoundation

final class StakingPoolJoinChoosePoolPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolJoinChoosePoolViewInput?
    private let router: StakingPoolJoinChoosePoolRouterInput
    private let interactor: StakingPoolJoinChoosePoolInteractorInput
    private let viewModelFactory: StakingPoolJoinChoosePoolViewModelFactoryProtocol
    private let inputAmount: Decimal
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let filterFactory: TitleSwitchTableViewCellModelFactoryProtocol

    private var selectedPoolId: String?
    private var pools: [StakingPool]?
    private var sort: PoolSortOption = .numberOfMembers

    // MARK: - Constructors

    init(
        interactor: StakingPoolJoinChoosePoolInteractorInput,
        router: StakingPoolJoinChoosePoolRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: StakingPoolJoinChoosePoolViewModelFactoryProtocol,
        inputAmount: Decimal,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        filterFactory: TitleSwitchTableViewCellModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.inputAmount = inputAmount
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.filterFactory = filterFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let cellViewModels = viewModelFactory.buildCellViewModels(
            pools: pools,
            locale: selectedLocale,
            cellsDelegate: self,
            selectedPoolId: selectedPoolId,
            sort: sort
        )

        view?.didReceive(cellViewModels: cellViewModels)
    }
}

// MARK: - StakingPoolJoinChoosePoolViewOutput

extension StakingPoolJoinChoosePoolPresenter: StakingPoolJoinChoosePoolViewOutput {
    func didLoad(view: StakingPoolJoinChoosePoolViewInput) {
        self.view = view
        interactor.setup(with: self)

        view.didReceive(locale: selectedLocale)

        view.didStartLoading()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapContinueButton() {
        guard let pool = pools?.first(where: { $0.id == selectedPoolId }) else {
            return
        }

        router.presentConfirm(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet,
            inputAmount: inputAmount,
            selectedPool: pool
        )
    }

    func didTapOptionsButton() {
        let sortOptions: [PoolSortOption] = [
            .totalStake(assetSymbol: chainAsset.asset.symbol.uppercased()),
            .numberOfMembers
        ]
        let options = filterFactory.createSortings(
            options: sortOptions,
            selectedOption: sort,
            locale: selectedLocale
        )

        router.presentOptions(options: options, callback: { [weak self] selectedIndex in
            self?.sort = sortOptions[selectedIndex]
            self?.provideViewModel()
        }, from: view)
    }
}

// MARK: - StakingPoolJoinChoosePoolInteractorOutput

extension StakingPoolJoinChoosePoolPresenter: StakingPoolJoinChoosePoolInteractorOutput {
    func didReceivePools(_ pools: [StakingPool]?) {
        self.pools = pools
        provideViewModel()

        view?.didStopLoading()
    }

    func didReceiveError(_ error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }
}

// MARK: - Localizable

extension StakingPoolJoinChoosePoolPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}

extension StakingPoolJoinChoosePoolPresenter: StakingPoolJoinChoosePoolModuleInput {}

extension StakingPoolJoinChoosePoolPresenter: StakingPoolListTableCellModelDelegate {
    func selectPool(poolId: String) {
        selectedPoolId = poolId
        provideViewModel()
    }

    func showPoolInfo(poolId: String) {
        guard let pool = pools?.first(where: { $0.id == poolId }) else {
            return
        }

        router.presentPoolInfo(
            stakingPool: pool,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }
}
