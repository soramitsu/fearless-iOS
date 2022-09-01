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
            locale: selectedLocale
        )

        view?.didReceive(confirmViewModel: viewModel)
    }

    private func provideFeeViewModel() {
        let feeViewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)

        view?.didReceive(feeViewModel: feeViewModel)
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
}

// MARK: - Localizable

extension StakingPoolJoinConfirmPresenter: Localizable {
    func applyLocalization() {}
}

extension StakingPoolJoinConfirmPresenter: StakingPoolJoinConfirmModuleInput {}
