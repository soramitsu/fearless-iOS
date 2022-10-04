import Foundation
import SoraFoundation
import BigInt

final class StakingPoolCreateConfirmPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolCreateConfirmViewInput?
    private let router: StakingPoolCreateConfirmRouterInput
    private let interactor: StakingPoolCreateConfirmInteractorInput

    private let createData: StakingPoolCreateData
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let viewModelFactory: StakingPoolCreateConfirmViewModelFactoryProtocol
    private let logger: LoggerProtocol

    private var priceData: PriceData?
    private var fee: Decimal?

    // MARK: - Constructors

    init(
        interactor: StakingPoolCreateConfirmInteractorInput,
        router: StakingPoolCreateConfirmRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: StakingPoolCreateConfirmViewModelFactoryProtocol,
        createData: StakingPoolCreateData,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.createData = createData
        self.balanceViewModelFactory = balanceViewModelFactory
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let data = CreatePoolConfirmData(
            amount: createData.amount,
            price: priceData,
            currency: createData.root.selectedCurrency,
            rootName: createData.root.name,
            poolId: "\(createData.poolId)",
            nominatorName: createData.nominator.name,
            stateTogglerName: createData.stateToggler.name
        )

        let viewModel = viewModelFactory.buildViewModel(
            data: data,
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

// MARK: - StakingPoolCreateConfirmViewOutput

extension StakingPoolCreateConfirmPresenter: StakingPoolCreateConfirmViewOutput {
    func didTapConfirmButton() {
        view?.didStartLoading()
        interactor.submit()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didLoad(view: StakingPoolCreateConfirmViewInput) {
        self.view = view
        interactor.setup(with: self)

        interactor.estimateFee()

        provideViewModel()
    }
}

// MARK: - StakingPoolCreateConfirmInteractorOutput

extension StakingPoolCreateConfirmPresenter: StakingPoolCreateConfirmInteractorOutput {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideFeeViewModel()
            provideViewModel()
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let feeValue = BigUInt(dispatchInfo.fee) {
                fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(createData.chainAsset.asset.precision))
            } else {
                fee = nil
            }

            provideFeeViewModel()
        case let .failure(error):
            logger.error(error.localizedDescription)
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

extension StakingPoolCreateConfirmPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
        provideFeeViewModel()
    }
}

extension StakingPoolCreateConfirmPresenter: StakingPoolCreateConfirmModuleInput {}
