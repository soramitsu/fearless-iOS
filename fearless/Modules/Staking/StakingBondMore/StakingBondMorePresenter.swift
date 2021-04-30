import SoraFoundation
import CommonWallet
import BigInt

final class StakingBondMorePresenter {
    let interactor: StakingBondMoreInteractorInputProtocol
    let wireframe: StakingBondMoreWireframeProtocol
    weak var view: StakingBondMoreViewProtocol?
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    var amount: Decimal = 0
    private let asset: WalletAsset
    private var priceData: PriceData?
    private var balance: Decimal?
    private var fee: Decimal?

    init(
        interactor: StakingBondMoreInteractorInputProtocol,
        wireframe: StakingBondMoreWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        asset: WalletAsset
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.asset = asset
    }

    private func estimateFee() {
        if let amount = StakingConstants.maxAmount.toSubstrateAmount(precision: asset.precision) {
            interactor.estimateFee(amount: amount)
        }
    }

    private func provideAmountInputViewModel() {
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(amount)
        view?.didReceiveInput(viewModel: viewModel)
    }

    private func provideFee() {
        if let fee = fee {
            let viewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
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
        estimateFee()
    }

    func handleContinueAction() {
        wireframe.showConfirmation(from: view)
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue

        provideAsset()
        estimateFee()
    }
}

extension StakingBondMorePresenter: StakingBondMoreInteractorOutputProtocol {
    func didReceive(paymentInfo: RuntimeDispatchInfo, for _: BigUInt) {
        if let feeValue = BigUInt(paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) {
            self.fee = fee
        } else {
            fee = nil
        }

        provideFee()
    }

    func didReceive(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        _ = wireframe.present(error: error, from: view, locale: locale)
    }

    func didReceive(price: PriceData?) {
        priceData = price
        provideAsset()
        provideFee()
    }

    func didReceive(balance: DyAccountData?) {
        if let availableValue = balance?.available {
            self.balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: asset.precision
            )
        } else {
            self.balance = 0.0
        }

        provideAsset()
    }
}
