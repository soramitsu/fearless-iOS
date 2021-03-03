import Foundation
import CommonWallet

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let rewardViewModelFactory: RewardViewModelFactoryProtocol
    let logger: LoggerProtocol

    private var priceData: PriceData?
    private var balance: Decimal?
    private var amount: Decimal?
    private var asset: WalletAsset
    private var increase: Decimal?
    private var calculator: RewardCalculatorEngineProtocol?

    init(logger: LoggerProtocol,
         asset: WalletAsset,
         balanceViewModelFactory: BalanceViewModelFactoryProtocol,
         rewardViewModelFactory: RewardViewModelFactoryProtocol) {
        self.logger = logger
        self.asset = asset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.rewardViewModelFactory = rewardViewModelFactory
    }

    private func provideAsset() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(amount ?? 0.0,
                                                                            balance: balance,
                                                                            priceData: priceData)
        view?.didReceiveAsset(viewModel: viewModel)
    }

    private func provideReward() {
        var payoutPercentage: Decimal?
        do {
            if let calculator = calculator {
                payoutPercentage = try calculator.calculateNetworkReturn(isCompound: false,
                                                                             period: .year)
            }
        } catch {
            logger.error("Can't calculate reward")
        }

        let curAmount = amount ?? 0.0
        let reward = curAmount * (payoutPercentage ?? 0.0)

        let monthlyViewModel = rewardViewModelFactory.createMonthlyRewardViewModel(amount: curAmount,
                                                                                   reward: reward,
                                                                                   priceData: priceData)

        let yearlyViewModel = rewardViewModelFactory.createYearlyRewardViewModel(amount: curAmount,
                                                                                 reward: reward,
                                                                                 priceData: priceData)

        view?.didReceiveRewards(monthlyViewModel: monthlyViewModel,
                                yearlyViewModel: yearlyViewModel)
    }

    private func provideAmountInputViewModel() {
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(amount)
        view?.didReceiveInput(viewModel: viewModel)
    }
}

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        provideReward()
        provideAmountInputViewModel()
        interactor.setup()
    }

    func performMainAction() {
        wireframe.showSetupAmount(from: view)
    }

    func performAccountAction() {
        logger.debug("Did select account")
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue
        provideAsset()
        provideReward()
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = balance {
            let newAmount = balance * Decimal(Double(percentage))

            if newAmount >= 0 {
                amount = newAmount

                provideAmountInputViewModel()
                provideAsset()
                provideReward()
            } else {
                wireframe.presentNotEnoughFunds(from: view)
            }
        }
    }
}

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        self.priceData = price
        provideAsset()
        provideReward()
    }

    func didReceive(balance: DyAccountData?) {
        if let availableValue = balance?.available {
            self.balance = Decimal.fromSubstrateAmount(availableValue,
                                                       precision: asset.precision)
        } else {
            self.balance = 0.0
        }

        provideAsset()
        provideReward()
    }

    func didReceive(selectedAddress: String) {
        let viewModel = StakingMainViewModel(address: selectedAddress)
        view?.didReceive(viewModel: viewModel)
    }

    func didReceive(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            logger.error("Did receive error: \(error)")
        }
    }

    func didReceive(calculator: RewardCalculatorEngineProtocol) {
        self.calculator = calculator
        provideReward()
    }

    func didReceive(calculatorError: Error) {
        let locale = view?.localizationManager?.selectedLocale
        if !wireframe.present(error: calculatorError, from: view, locale: locale) {
            logger.error("Did receive error: \(calculatorError)")
        }
    }
}
