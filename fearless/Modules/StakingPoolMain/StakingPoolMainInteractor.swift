import UIKit

final class StakingPoolMainInteractor {
    // MARK: - Private properties

    private weak var output: StakingPoolMainInteractorOutput?
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let selectedWalletSettings: SelectedWalletSettings
    private let stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    private let settings: StakingAssetSettings
    private let rewardCalculationService: RewardCalculatorServiceProtocol
    private var chainAsset: ChainAsset
    private let operationQueue: OperationQueue

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        settings: StakingAssetSettings,
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol,
        rewardCalculationService: RewardCalculatorServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainAsset: ChainAsset,
        operationQueue: OperationQueue
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.selectedWalletSettings = selectedWalletSettings
        self.settings = settings
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
        self.rewardCalculationService = rewardCalculationService
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
        self.operationQueue = operationQueue
    }

    private func updateAfterChainAssetSave() {
        guard let newSelectedChainAsset = settings.value else {
            return
        }

        chainAsset = newSelectedChainAsset
        updateWithChainAsset(chainAsset)
    }

    private func fetchRewardCalculator() {
        let fetchRewardCalculatorOperation = rewardCalculationService.fetchCalculatorOperation()

        fetchRewardCalculatorOperation.completionBlock = { [weak self] in
            let rewardCalculatorEngine = try? fetchRewardCalculatorOperation.extractNoCancellableResultData()
            self?.output?.didReceive(rewardCalculatorEngine: rewardCalculatorEngine)
        }

        operationQueue.addOperation(fetchRewardCalculatorOperation)
    }
}

// MARK: - StakingPoolMainInteractorInput

extension StakingPoolMainInteractor: StakingPoolMainInteractorInput {
    func setup(with output: StakingPoolMainInteractorOutput) {
        self.output = output

        updateWithChainAsset(chainAsset)

        rewardCalculationService.setup()

        fetchRewardCalculator()
    }

    func updateWithChainAsset(_ chainAsset: ChainAsset) {
        clear(singleValueProvider: &priceProvider)

        self.chainAsset = chainAsset

        if let wallet = selectedWalletSettings.value,
           let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
        }

        output?.didReceive(chainAsset: chainAsset)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }
    }

    func save(chainAsset: ChainAsset) {
        guard self.chainAsset.chainAssetId != chainAsset.chainAssetId else {
            return
        }

        settings.save(value: chainAsset, runningCompletionIn: .main) { [weak self] _ in
            self?.updateAfterChainAssetSave()
//            self?.updateAfterSelectedAccountChange()
        }
    }
}

extension StakingPoolMainInteractor: AnyProviderAutoCleaning {}

extension StakingPoolMainInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {
        switch result {
        case let .success(accountInfo):
            output?.didReceive(accountInfo: accountInfo)
        case let .failure(error):
            output?.didReceive(balanceError: error)
        }
    }
}

extension StakingPoolMainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            output?.didReceive(priceData: priceData)
        case let .failure(error):
            output?.didReceive(priceError: error)
        }
    }
}
