import Foundation

final class StakingUnbondSetupPresenter {
    weak var view: StakingUnbondSetupViewProtocol?
    let wireframe: StakingUnbondSetupWireframeProtocol
    let interactor: StakingUnbondSetupInteractorInputProtocol

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    let logger: LoggerProtocol?
    let chain: Chain

    private var stakingLedger: DyStakingLedger?
    private var accountInfo: DyAccountInfo?
    private var inputAmount: Decimal?
    private var priceData: PriceData?

    init(
        interactor: StakingUnbondSetupInteractorInputProtocol,
        wireframe: StakingUnbondSetupWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chain: Chain,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chain = chain
        self.logger = logger
    }

    private func provideInputViewModel() {
        let inputView = balanceViewModelFactory.createBalanceInputViewModel(nil)
        view?.didReceiveInput(viewModel: inputView)
    }

    private func provideFeeViewModel() {
        view?.didReceiveFee(viewModel: nil)
    }

    private func provideAssetViewModel() {
        let bondedDecimal: Decimal? = {
            guard let bonded = stakingLedger?.active else {
                return nil
            }

            return Decimal.fromSubstrateAmount(bonded, precision: chain.addressType.precision)
        }()

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount ?? 0.0,
            balance: bondedDecimal,
            priceData: priceData
        )

        view?.didReceiveAsset(viewModel: viewModel)
    }

    private func provideBondingDuration() {}
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupPresenterProtocol {
    func setup() {
        provideInputViewModel()
        provideFeeViewModel()
        provideBondingDuration()
        provideAssetViewModel()

        interactor.setup()
    }

    func selectAmountPercentage(_: Float) {}
    func updateAmount(_ amount: Decimal) {
        inputAmount = amount
        provideAssetViewModel()
    }

    func proceed() {}
    func close() {
        wireframe.close(view: view)
    }
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupInteractorOutputProtocol {
    func didReceiveAccountInfo(result: Result<DyAccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            self.accountInfo = accountInfo
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<DyStakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            self.stakingLedger = stakingLedger
            provideAssetViewModel()
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideAssetViewModel()
            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }
}
