import Foundation
import SoraFoundation
import SSFModels

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

    private var palletId: Data?
    private var validators: YourValidatorsModel?

    private var stakingPool: StakingPool?
    private var editedRoles: StakingPoolRoles?
    private var activeEraInfo: ActiveEraInfo?
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
            let validators = validators,
            let stakingPool = stakingPool,
            let editedRoles = editedRoles
        else {
            return
        }

        viewLoaded = true
        view?.didStopLoading()

        let viewModel = viewModelFactory.buildViewModel(
            validators: validators,
            stakingPool: stakingPool,
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

    private func fetchValidators() {
        guard let stashAccountId = fetchPoolAccount(for: .stash),
              let activeEraInfo = activeEraInfo
        else {
            return
        }

        interactor.fetchPoolNomination(
            poolStashAccountId: stashAccountId,
            activeEra: activeEraInfo.index
        )
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
            fetchValidators()
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

    func bouncerDidTapped() {
        router.showWalletManagment(
            contextTag: StakingPoolInfoContextTag.bouncer.rawValue,
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
    func didReceive(activeEra: Result<ActiveEraInfo?, Error>) {
        switch activeEra {
        case let .success(activeEraInfo):
            self.activeEraInfo = activeEraInfo

            fetchValidators()
        case let .failure(error):
            logger?.error("StakingPoolJoinConfigPresenter.didReceive.activeEra.error: \(error)")
        }
    }

    func didReceive(palletIdResult: Result<Data, Error>) {
        switch palletIdResult {
        case let .success(palletId):
            self.palletId = palletId
            provideViewModel()
            fetchValidators()
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }

    func didReceive(stakingPool: StakingPool?) {
        self.stakingPool = stakingPool

        if let stakingPool = stakingPool {
            editedRoles = stakingPool.info.roles
        }

        provideStatus()
        provideViewModel()
        fetchValidators()
    }

    func didReceive(error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveValidators(validators: YourValidatorsModel) {
        self.validators = validators
        provideViewModel()
    }

    func didReceive(nomination: Nomination?) {
        self.nomination = nomination
        provideStatus()
        provideViewModel()
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
        case bouncer
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
        case .bouncer:
            editedRoles?.bouncer = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        case .root:
            editedRoles?.root = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        }

        provideViewModel()
    }
}
