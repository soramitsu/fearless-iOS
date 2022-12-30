import Foundation
import SoraFoundation
import BigInt

final class PoolRolesConfirmPresenter {
    // MARK: Private properties

    private weak var view: PoolRolesConfirmViewInput?
    private let router: PoolRolesConfirmRouterInput
    private let interactor: PoolRolesConfirmInteractorInput
    private let logger: LoggerProtocol
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let viewModelFactory: PoolRolesConfirmViewModelFactoryProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let roles: StakingPoolRoles

    private var priceData: PriceData?
    private var fee: Decimal?
    private var accounts: [MetaAccountModel]?

    // MARK: - Constructors

    init(
        interactor: PoolRolesConfirmInteractorInput,
        router: PoolRolesConfirmRouterInput,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        viewModelFactory: PoolRolesConfirmViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        roles: StakingPoolRoles,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.balanceViewModelFactory = balanceViewModelFactory
        self.viewModelFactory = viewModelFactory
        self.roles = roles
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideFeeViewModel() {
        let feeViewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)

        view?.didReceive(feeViewModel: feeViewModel)
    }

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(roles: roles, accounts: accounts)
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - PoolRolesConfirmViewOutput

extension PoolRolesConfirmPresenter: PoolRolesConfirmViewOutput {
    func didLoad(view: PoolRolesConfirmViewInput) {
        self.view = view
        interactor.setup(with: self)

        provideViewModel()

        interactor.estimateFee()
    }

    func didTapConfirmButton() {
        view?.didStartLoading()
        interactor.submit()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }
}

// MARK: - PoolRolesConfirmInteractorOutput

extension PoolRolesConfirmPresenter: PoolRolesConfirmInteractorOutput {
    func didReceive(accounts: [MetaAccountModel]) {
        self.accounts = accounts
        provideViewModel()
    }

    func didReceive(error: Error) {
        logger.error(error.localizedDescription)
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideFeeViewModel()
        case let .failure(error):
            logger.error(error.localizedDescription)
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
            logger.error(error.localizedDescription)
        }
    }

    func didReceive(extrinsicResult: SubmitExtrinsicResult) {
        view?.didStopLoading()

        switch extrinsicResult {
        case .success:
            let title = R.string.localizable
                .commonTransactionSubmitted(preferredLanguages: selectedLocale.rLanguages)
            router.finish(view: view)
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

extension PoolRolesConfirmPresenter: Localizable {
    func applyLocalization() {}
}

extension PoolRolesConfirmPresenter: PoolRolesConfirmModuleInput {}
