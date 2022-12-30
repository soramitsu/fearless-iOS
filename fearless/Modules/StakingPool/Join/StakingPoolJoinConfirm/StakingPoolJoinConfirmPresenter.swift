import Foundation
import SoraFoundation
import BigInt

final class StakingPoolJoinConfirmPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolJoinConfirmViewInput?
    private let router: StakingPoolJoinConfirmRouterInput
    private let interactor: StakingPoolJoinConfirmInteractorInput
    private let viewModelFactory: StakingPoolJoinConfirmViewModelFactoryProtocol
    private let inputAmount: Decimal
    private let pool: StakingPool
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let logger: LoggerProtocol?

    private var priceData: PriceData?
    private var fee: Decimal?
    private var palletId: Data?
    private var nomination: Nomination?
    private var nominationReceived: Bool = false

    // MARK: - Constructors

    init(
        interactor: StakingPoolJoinConfirmInteractorInput,
        router: StakingPoolJoinConfirmRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: StakingPoolJoinConfirmViewModelFactoryProtocol,
        inputAmount: Decimal,
        pool: StakingPool,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.inputAmount = inputAmount
        self.pool = pool
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            amount: inputAmount,
            pool: pool,
            wallet: wallet,
            locale: selectedLocale,
            poolNomination: nomination,
            nominationReceived: nominationReceived
        )

        view?.didReceive(confirmViewModel: viewModel)
    }

    private func provideFeeViewModel() {
        let feeViewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)

        view?.didReceive(feeViewModel: feeViewModel)
    }

    private func fetchPoolAccount(for type: PoolAccount) -> AccountId? {
        guard
            let modPrefix = "modl".data(using: .utf8),
            let palletIdData = palletId,
            let poolIdUintValue = UInt(pool.id)
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

    private func providePoolNomination() {
        guard let stashAccountId = fetchPoolAccount(for: .stash) else {
            return
        }

        interactor.fetchPoolNomination(poolStashAccountId: stashAccountId)
    }
}

// MARK: - StakingPoolJoinConfirmViewOutput

extension StakingPoolJoinConfirmPresenter: StakingPoolJoinConfirmViewOutput {
    func didLoad(view: StakingPoolJoinConfirmViewInput) {
        self.view = view
        interactor.setup(with: self)

        provideViewModel()
        interactor.estimateFee()

        view.didReceive(feeViewModel: nil)
    }

    func didTapConfirmButton() {
        view?.didStartLoading()
        interactor.submit()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }
}

// MARK: - StakingPoolJoinConfirmInteractorOutput

extension StakingPoolJoinConfirmPresenter: StakingPoolJoinConfirmInteractorOutput {
    func didReceive(error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("StakingPoolJoinConfigPresenter.didReceivePriceData.error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let feeValue = BigUInt(dispatchInfo.fee) {
                fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(chainAsset.asset.precision))
            } else {
                fee = nil
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("StakingPoolJoinConfigPresenter.didReceiveFee.error: \(error)")
        }
    }

    func didReceive(extrinsicResult: SubmitExtrinsicResult) {
        view?.didStopLoading()

        switch extrinsicResult {
        case .success:
            let title = R.string.localizable
                .commonTransactionSubmitted(preferredLanguages: selectedLocale.rLanguages)

            router.complete(on: view, title: title)
        case let .failure(error):
            guard let view = view else {
                return
            }

            if !router.present(error: error, from: view, locale: selectedLocale) {
                router.presentExtrinsicFailed(from: view, locale: selectedLocale)
            }
        }
    }

    func didReceive(palletIdResult: Result<Data, Error>) {
        switch palletIdResult {
        case let .success(palletId):
            self.palletId = palletId
            providePoolNomination()
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }

    func didReceive(nomination: Nomination?) {
        nominationReceived = true
        self.nomination = nomination
        provideViewModel()
    }
}

// MARK: - Localizable

extension StakingPoolJoinConfirmPresenter: Localizable {
    func applyLocalization() {}
}

extension StakingPoolJoinConfirmPresenter: StakingPoolJoinConfirmModuleInput {}
