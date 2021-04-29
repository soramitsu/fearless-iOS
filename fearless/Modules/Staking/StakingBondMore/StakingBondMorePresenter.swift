import SoraFoundation

final class StakingBondMorePresenter {
    let interactor: StakingBondMoreInteractorInputProtocol
    let wireframe: StakingBondMoreWireframeProtocol
    weak var view: StakingBondMoreViewProtocol?
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    var amount: Decimal = 0
    private var priceData: PriceData?
    private var balance: Decimal?

    init(
        interactor: StakingBondMoreInteractorInputProtocol,
        wireframe: StakingBondMoreWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func provideAmountInputViewModel() {
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(amount)
        view?.didReceiveInput(viewModel: viewModel)
    }

    private func provideAsset() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            amount,
            balance: balance,
            priceData: priceData
        )
        view?.didReceiveAsset(viewModel: viewModel)
    }
}

extension StakingBondMorePresenter: StakingBondMorePresenterProtocol {
    func setup() {
        provideAmountInputViewModel()
        interactor.setup()
    }

    func handleContinueAction() {
        wireframe.showConfirmation(from: view)
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue

        provideAsset()
//        provideRewardDestination()
//        scheduleFeeEstimation()
    }
}

extension StakingBondMorePresenter: StakingBondMoreInteractorOutputProtocol {
    func didReceive(error _: Error) {}

    func didReceive(price _: PriceData?) {}

    func didReceive(balance _: DyAccountData?) {}
}
