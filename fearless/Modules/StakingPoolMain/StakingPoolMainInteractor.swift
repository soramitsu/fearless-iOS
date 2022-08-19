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

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        settings: StakingAssetSettings,
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol,
        rewardCalculationService: RewardCalculatorServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.selectedWalletSettings = selectedWalletSettings
        self.settings = settings
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
        self.rewardCalculationService = rewardCalculationService
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
    }

    private func updateAfterChainAssetSave() {
        guard let newSelectedChainAsset = settings.value else {
            return
        }

        chainAsset = newSelectedChainAsset
        updateWithChainAsset(chainAsset)
    }
}

// MARK: - StakingPoolMainInteractorInput

extension StakingPoolMainInteractor: StakingPoolMainInteractorInput {
    func setup(with output: StakingPoolMainInteractorOutput) {
        self.output = output

        updateWithChainAsset(chainAsset)
    }

    func updateWithChainAsset(_ chainAsset: ChainAsset) {
        self.chainAsset = chainAsset

        if let wallet = selectedWalletSettings.value, let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
        }

        output?.didReceive(chainAsset: chainAsset)
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
