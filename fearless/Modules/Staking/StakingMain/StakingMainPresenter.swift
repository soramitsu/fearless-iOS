import Foundation
import CommonWallet

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!

    private var balanceViewModelFactory: BalanceViewModelFactoryProtocol?
    private var rewardViewModelFactory: RewardViewModelFactoryProtocol?
    let viewModelFacade: StakingViewModelFacadeProtocol
    let logger: LoggerProtocol?

    private var priceData: PriceData?
    private var balance: Decimal?
    private var amount: Decimal?
    private var increase: Decimal?
    private var calculator: RewardCalculatorEngineProtocol?

    private var chain: Chain?

    init(viewModelFacade: StakingViewModelFacadeProtocol, logger: LoggerProtocol?) {
        self.viewModelFacade = viewModelFacade
        self.logger = logger
    }

    private func provideAsset() {
        guard let viewModelFactory = balanceViewModelFactory else {
            return
        }

        let viewModel = viewModelFactory.createAssetBalanceViewModel(amount ?? 0.0,
                                                                     balance: balance,
                                                                     priceData: priceData)
        view?.didReceiveAsset(viewModel: viewModel)
    }

    private func provideReward() {
        guard let viewModelFactory = rewardViewModelFactory else {
            return
        }

        var payoutPercentage: Decimal?
        do {
            if let calculator = calculator {
                payoutPercentage = try calculator.calculateNetworkReturn(isCompound: false,
                                                                             period: .year)
            }
        } catch {
            logger?.error("Can't calculate reward")
        }

        let curAmount = amount ?? 0.0
        let reward = curAmount * (payoutPercentage ?? 0.0)

        let monthlyViewModel = viewModelFactory.createMonthlyRewardViewModel(amount: curAmount,
                                                                             reward: reward,
                                                                             priceData: priceData)

        let yearlyViewModel = viewModelFactory.createYearlyRewardViewModel(amount: curAmount,
                                                                           reward: reward,
                                                                           priceData: priceData)

        view?.didReceiveRewards(monthlyViewModel: monthlyViewModel,
                                yearlyViewModel: yearlyViewModel)
    }

    private func provideAmountInputViewModel() {
        guard let viewModelFactory = balanceViewModelFactory else {
            return
        }

        let viewModel = viewModelFactory.createBalanceInputViewModel(amount)
        view?.didReceiveInput(viewModel: viewModel)
    }
}

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func performMainAction() {
        wireframe.showSetupAmount(from: view)
    }

    func performAccountAction() {
        logger?.debug("Did select account")
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
            } else if let view = view {
                wireframe.presentAmountTooHigh(from: view,
                                               locale: view.localizationManager?.selectedLocale)
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
        if let availableValue = balance?.available, let chain = chain {
            self.balance = Decimal.fromSubstrateAmount(availableValue,
                                                       precision: chain.addressType.precision)
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
            logger?.error("Did receive error: \(error)")
        }
    }

    func didReceive(calculator: RewardCalculatorEngineProtocol) {
        self.calculator = calculator
        provideReward()
    }

    func didReceive(calculatorError: Error) {
        let locale = view?.localizationManager?.selectedLocale
        if !wireframe.present(error: calculatorError, from: view, locale: locale) {
            logger?.error("Did receive error: \(calculatorError)")
        }
    }

    func didReceive(newChain: Chain) {
        self.chain = newChain
        self.balanceViewModelFactory = viewModelFacade.createBalanceViewModelFactory(for: newChain)
        self.rewardViewModelFactory = viewModelFacade.createRewardViewModelFactory(for: newChain)

        self.amount = nil
        self.calculator = nil
        self.priceData = nil
        self.increase = nil

        provideReward()
        provideAsset()
        provideAmountInputViewModel()
    }
}
