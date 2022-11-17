import Foundation
import SoraFoundation

final class StakingPoolInfoPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolInfoViewInput?
    private let router: StakingPoolInfoRouterInput
    private let interactor: StakingPoolInfoInteractorInput
    private let viewModelFactory: StakingPoolInfoViewModelFactoryProtocol
    private let stakingPool: StakingPool
    private let chainAsset: ChainAsset
    private let logger: LoggerProtocol?
    private let wallet: MetaAccountModel
    private var viewLoaded: Bool = false

    private var priceData: PriceData?
    private var palletId: Data?
    private var electedValidators: [ElectedValidatorInfo]?

    // MARK: - Constructors

    init(
        interactor: StakingPoolInfoInteractorInput,
        router: StakingPoolInfoRouterInput,
        viewModelFactory: StakingPoolInfoViewModelFactoryProtocol,
        stakingPool: StakingPool,
        chainAsset: ChainAsset,
        logger: LoggerProtocol?,
        wallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.logger = logger
        self.stakingPool = stakingPool
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard
            let stashAccount = fetchPoolAccount(for: .stash),
            let electedValidators = electedValidators
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
            locale: selectedLocale
        )
        view?.didReceive(viewModel: viewModel)
    }

    private func fetchPoolAccount(for type: PoolAccount) -> AccountId? {
        guard
            let modPrefix = "modl".data(using: .utf8),
            let palletIdData = palletId,
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
}

// MARK: - StakingPoolInfoViewOutput

extension StakingPoolInfoPresenter: StakingPoolInfoViewOutput {
    func didLoad(view: StakingPoolInfoViewInput) {
        self.view = view

        interactor.setup(with: self)

        provideViewModel()
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
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}

// MARK: - Localizable

extension StakingPoolInfoPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension StakingPoolInfoPresenter: StakingPoolInfoModuleInput {}
