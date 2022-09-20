import Foundation
import SoraFoundation

final class StakingPoolMainPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolMainViewInput?
    private let router: StakingPoolMainRouterInput
    private let interactor: StakingPoolMainInteractorInput
    private var balanceViewModelFactory: BalanceViewModelFactoryProtocol {
        didSet {
            viewModelFactory.replaceBalanceViewModelFactory(balanceViewModelFactory: balanceViewModelFactory)
        }
    }

    private weak var moduleOutput: StakingMainModuleOutput?
    private let viewModelFactory: StakingPoolMainViewModelFactoryProtocol

    private var wallet: MetaAccountModel
    private var chainAsset: ChainAsset
    private var accountInfo: AccountInfo?
    private var balance: Decimal?
    private var rewardCalculatorEngine: RewardCalculatorEngineProtocol?
    private var priceData: PriceData?
    private var era: EraIndex?
    private var eraStakersInfo: EraStakersInfo?
    private var eraCountdown: EraCountdown?
    private var stakeInfo: StakingPoolMember?

    private var inputResult: AmountInputResult?

    // MARK: - Constructors

    init(
        interactor: StakingPoolMainInteractorInput,
        router: StakingPoolMainRouterInput,
        localizationManager: LocalizationManagerProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        moduleOutput: StakingMainModuleOutput?,
        viewModelFactory: StakingPoolMainViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
        self.router = router
        self.balanceViewModelFactory = balanceViewModelFactory
        self.moduleOutput = moduleOutput
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideBalanceViewModel() {
        if let availableValue = accountInfo?.data.available {
            balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: Int16(chainAsset.asset.precision)
            )
        } else {
            balance = 0.0
        }

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
            balance ?? 0.0,
            priceData: nil
        ).value(for: selectedLocale)

        DispatchQueue.main.async {
            self.view?.didReceiveBalanceViewModel(balanceViewModel)
        }
    }

    private func provideRewardEstimationViewModel() {
        let viewModel = viewModelFactory.createEstimationViewModel(
            for: chainAsset,
            accountInfo: accountInfo,
            amount: inputResult?.absoluteValue(from: balance ?? 0.0),
            priceData: priceData,
            calculatorEngine: rewardCalculatorEngine
        )

        DispatchQueue.main.async {
            self.view?.didReceiveEstimationViewModel(viewModel)
        }
    }

    private func provideStakeInfoViewModel() {
        guard let stakeInfo = stakeInfo else {
            view?.didReceiveNominatorStateViewModel(nil)

            return
        }

        let viewModel = viewModelFactory.buildNominatorStateViewModel(
            stakeInfo: stakeInfo,
            priceData: priceData,
            chainAsset: chainAsset,
            era: eraStakersInfo?.activeEra
        )

        view?.didReceiveNominatorStateViewModel(viewModel)
    }
}

// MARK: - StakingPoolMainViewOutput

extension StakingPoolMainPresenter: StakingPoolMainViewOutput {
    func didLoad(view: StakingPoolMainViewInput) {
        self.view = view
        interactor.setup(with: self)

        view.didReceiveNominatorStateViewModel(nil)
    }

    func didTapSelectAsset() {
        router.showChainAssetSelection(
            from: view,
            type: .pool(chainAsset: chainAsset),
            delegate: self
        )
    }

    func didTapStartStaking() {
        router.showSetupAmount(
            from: view,
            amount: inputResult?.absoluteValue(from: balance ?? 0.0),
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func didTapAccountSelection() {
        router.showAccountsSelection(from: view)
    }

    func performRewardInfoAction() {
        guard let rewardCalculator = rewardCalculatorEngine else {
            return
        }

        let maxReward = rewardCalculator.calculateMaxReturn(isCompound: true, period: .year)
        let avgReward = rewardCalculator.calculateAvgReturn(isCompound: true, period: .year)
        let maxRewardTitle = rewardCalculator.maxEarningsTitle(locale: selectedLocale)
        let avgRewardTitle = rewardCalculator.avgEarningTitle(locale: selectedLocale)

        router.showRewardDetails(
            from: view,
            maxReward: (maxRewardTitle, maxReward),
            avgReward: (avgRewardTitle, avgReward)
        )
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)

        provideRewardEstimationViewModel()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideRewardEstimationViewModel()
    }

    func networkInfoViewDidChangeExpansion(isExpanded: Bool) {
        interactor.saveNetworkInfoViewExpansion(isExpanded: isExpanded)
    }
}

// MARK: - StakingPoolMainInteractorOutput

extension StakingPoolMainPresenter: StakingPoolMainInteractorOutput {
    func didReceive(era: EraIndex) {
        self.era = era
    }

    func didReceive(eraStakersInfo: EraStakersInfo) {
        self.eraStakersInfo = eraStakersInfo

        provideStakeInfoViewModel()
    }

    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) {
        switch eraCountdownResult {
        case let .success(eraCountdown):
            self.eraCountdown = eraCountdown
        case let .failure(error):
            break
        }
    }

    func didReceive(eraStakersInfoError _: Error) {}

    func didReceive(accountInfo: AccountInfo?) {
        self.accountInfo = accountInfo

        provideBalanceViewModel()
        provideRewardEstimationViewModel()
    }

    func didReceive(balanceError _: Error) {}

    func didReceive(chainAsset: ChainAsset) {
        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        self.chainAsset = chainAsset

        provideBalanceViewModel()
        provideRewardEstimationViewModel()

        view?.didReceiveChainAsset(chainAsset)
    }

    func didReceive(rewardCalculatorEngine: RewardCalculatorEngineProtocol?) {
        self.rewardCalculatorEngine = rewardCalculatorEngine

        provideRewardEstimationViewModel()
    }

    func didReceive(priceError _: Error) {}

    func didReceive(priceData: PriceData?) {
        self.priceData = priceData

        provideRewardEstimationViewModel()
        provideStakeInfoViewModel()
    }

    func didReceive(wallet: MetaAccountModel) {
        self.wallet = wallet

        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        provideBalanceViewModel()
        provideRewardEstimationViewModel()
    }

    func didReceive(networkInfo: StakingPoolNetworkInfo) {
        let viewModels = viewModelFactory.buildNetworkInfoViewModels(networkInfo: networkInfo, chainAsset: chainAsset)
        view?.didReceiveNetworkInfoViewModels(viewModels)
    }

    func didReceive(networkInfoError _: Error) {}

    func didReceive(stakeInfo: StakingPoolMember?) {
        self.stakeInfo = stakeInfo
        provideStakeInfoViewModel()
    }

    func didReceive(stakeInfoError _: Error) {}
}

// MARK: - Localizable

extension StakingPoolMainPresenter: Localizable {
    func applyLocalization() {}
}

extension StakingPoolMainPresenter: StakingPoolMainModuleInput {}

extension StakingPoolMainPresenter: AssetSelectionDelegate {
    func assetSelection(
        view _: ChainSelectionViewProtocol,
        didCompleteWith chainAsset: ChainAsset,
        context: Any?
    ) {
        guard let type = context as? AssetSelectionStakingType, let chainAsset = type.chainAsset else {
            return
        }

        interactor.save(chainAsset: chainAsset)

        switch type {
        case .normal:
            moduleOutput?.didSwitchStakingType(type)
        case .pool:
            break
        }
    }
}
