import Foundation
import SoraFoundation

final class StakingPoolInfoPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolInfoViewInput?
    private let router: StakingPoolInfoRouterInput
    private let interactor: StakingPoolInfoInteractorInput
    private let viewModelFactory: StakingPoolInfoViewModelFactoryProtocol
    private let chainAsset: ChainAsset
    private let logger: LoggerProtocol?
    private let wallet: MetaAccountModel
    private var viewLoaded: Bool = false
    private var status: NominationViewStatus?

    private var priceData: PriceData?
    private var palletId: Data?
    private var electedValidators: [ElectedValidatorInfo]?

    private var stakingPool: StakingPool?
    private var editedRoles: StakingPoolRoles?

    private var nomination: Nomination?
    private var eraStakersInfo: EraStakersInfo?

    // MARK: - Constructors

    init(
        interactor: StakingPoolInfoInteractorInput,
        router: StakingPoolInfoRouterInput,
        viewModelFactory: StakingPoolInfoViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        logger: LoggerProtocol?,
        wallet: MetaAccountModel,
        status: NominationViewStatus?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.logger = logger
        self.wallet = wallet
        self.status = status

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard
            let stashAccount = fetchPoolAccount(for: .stash),
            let electedValidators = electedValidators,
            let stakingPool = stakingPool,
            let editedRoles = editedRoles
        else {
            return
        }

        viewLoaded = true
        view?.didStopLoading()

        let viewModel = viewModelFactory.buildViewModel(
            stashAccount: stashAccount,
            electedValidators: electedValidators,
            stakingPool: stakingPool,
            priceData: priceData,
            locale: selectedLocale,
            roles: editedRoles,
            wallet: wallet
        )
        view?.didReceive(viewModel: viewModel)
    }

    private func provideStatus() {
        guard let poolInfo = stakingPool
        else {
            return
        }

        let status = viewModelFactory.buildStatus(
            poolInfo: poolInfo,
            era: eraStakersInfo?.activeEra,
            nomination: nomination
        )

        view?.didReceive(status: status)
    }

    private func fetchPoolAccount(for type: PoolAccount) -> AccountId? {
        guard
            let modPrefix = "modl".data(using: .utf8),
            let palletIdData = palletId,
            let stakingPool = stakingPool,
            let poolIdUintValue = UInt(stakingPool.id)
        else {
            return nil
        }

        var index: UInt8 = type.rawValue
        var poolIdValue = poolIdUintValue
        let indexData = Data(
            bytes: &index,
            count: MemoryLayout.size(ofValue: index)
        )

        let poolIdSize = MemoryLayout.size(ofValue: poolIdValue)
        let poolIdData = Data(
            bytes: &poolIdValue,
            count: poolIdSize
        )

        let emptyH256 = [UInt8](repeating: 0, count: 32)
        let poolAccountId = modPrefix + palletIdData + indexData + poolIdData + emptyH256

        return poolAccountId[0 ... 31]
    }

    private func fetchPoolNomination() {
        guard
            let poolStashAccountId = fetchPoolAccount(for: .stash) else {
            return
        }

        interactor.fetchPoolNomination(poolStashAccountId: poolStashAccountId)
    }
}

// MARK: - StakingPoolInfoViewOutput

extension StakingPoolInfoPresenter: StakingPoolInfoViewOutput {
    func didLoad(view: StakingPoolInfoViewInput) {
        self.view = view

        interactor.setup(with: self)

        provideViewModel()
        view.didReceive(status: status)
        if status == nil {
            fetchPoolNomination()
        }
    }

    func willAppear(view: StakingPoolInfoViewInput) {
        if !viewLoaded {
            view.didStartLoading()
        }
    }

    func didTapCloseButton() {
        router.dismiss(view: view)
    }

    func didTapValidators() {
        router.proceedToSelectValidatorsStart(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func nominatorDidTapped() {
        router.showWalletManagment(
            contextTag: StakingPoolInfoContextTag.nominator.rawValue,
            from: view,
            moduleOutput: self
        )
    }

    func stateTogglerDidTapped() {
        router.showWalletManagment(
            contextTag: StakingPoolInfoContextTag.stateToggler.rawValue,
            from: view,
            moduleOutput: self
        )
    }

    func rootDidTapped() {
        router.showWalletManagment(
            contextTag: StakingPoolInfoContextTag.root.rawValue,
            from: view,
            moduleOutput: self
        )
    }

    func saveRolesDidTapped() {
        guard let stakingPool = stakingPool,
              let editedRoles = editedRoles
        else {
            return
        }

        router.showUpdateRoles(
            roles: editedRoles,
            poolId: stakingPool.id,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }

    func copyAddressTapped() {
        router.presentStatus(with: AddressCopiedEvent(locale: selectedLocale), animated: true)
    }
}

// MARK: - StakingPoolInfoInteractorOutput

extension StakingPoolInfoPresenter: StakingPoolInfoInteractorOutput {
    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>) {
        switch result {
        case let .success(electedValidators):
            self.electedValidators = electedValidators
            provideViewModel()
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideViewModel()
        case let .failure(error):
            logger?.error("StakingPoolJoinConfigPresenter.didReceivePriceData.error: \(error)")
        }
    }

    func didReceive(palletIdResult: Result<Data, Error>) {
        switch palletIdResult {
        case let .success(palletId):
            self.palletId = palletId
            provideViewModel()
            if status == nil {
                fetchPoolNomination()
            }
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }

    func didReceive(stakingPool: StakingPool?) {
        self.stakingPool = stakingPool

        if let stakingPool = stakingPool {
            editedRoles = stakingPool.info.roles
        }

        if status == nil {
            fetchPoolNomination()
        }

        provideViewModel()
    }

    func didReceive(error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceive(nomination: Nomination?) {
        self.nomination = nomination
        provideStatus()
    }

    func didReceive(eraStakersInfo: EraStakersInfo) {
        self.eraStakersInfo = eraStakersInfo
        provideStatus()
    }
}

// MARK: - Localizable

extension StakingPoolInfoPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension StakingPoolInfoPresenter: StakingPoolInfoModuleInput {
    func didChange(status: NominationViewStatus) {
        self.status = status
        view?.didReceive(status: status)
    }
}

extension StakingPoolInfoPresenter: WalletsManagmentModuleOutput {
    private enum StakingPoolInfoContextTag: Int {
        case nominator = 0
        case stateToggler
        case root
    }

    func selectedWallet(_ wallet: MetaAccountModel, for contextTag: Int) {
        guard let contextTag = StakingPoolInfoContextTag(rawValue: contextTag)
        else {
            return
        }

        switch contextTag {
        case .nominator:
            editedRoles?.nominator = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        case .stateToggler:
            editedRoles?.stateToggler = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        case .root:
            editedRoles?.root = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        }

        provideViewModel()
    }
}
