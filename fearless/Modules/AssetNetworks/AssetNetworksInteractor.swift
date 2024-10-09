import UIKit
import SSFModels
import RobinHood

final class AssetNetworksInteractor {
    // MARK: - Private properties

    private weak var output: AssetNetworksInteractorOutput?
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter
    private let chainsIssuesCenter: ChainsIssuesCenter
    private let chainSettingsRepository: AsyncAnyRepository<ChainSettings>

    private let chainAsset: ChainAsset
    private let chainAssetFetching: ChainAssetFetchingProtocol

    private var availableChainAssets: [ChainAsset] = []

    init(
        chainAsset: ChainAsset,
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter,
        chainsIssuesCenter: ChainsIssuesCenter,
        chainSettingsRepository: AsyncAnyRepository<ChainSettings>
    ) {
        self.chainAsset = chainAsset
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.chainsIssuesCenter = chainsIssuesCenter
        self.chainSettingsRepository = chainSettingsRepository
    }

    private func getChainSettings() {
        Task {
            let settings = try await chainSettingsRepository.fetchAll()
            output?.didReceive(chainSettings: settings)
        }
    }
}

// MARK: - AssetNetworksInteractorInput

extension AssetNetworksInteractor: AssetNetworksInteractorInput {
    func setup(with output: AssetNetworksInteractorOutput) {
        self.output = output
        chainsIssuesCenter.addIssuesListener(self, getExisting: true)
        getAvailableChainAssets()
    }

    private func getAvailableChainAssets() {
        chainAssetFetching.fetch(
            shouldUseCache: true,
            filters: [.assetNames([chainAsset.asset.symbol, "xc\(chainAsset.asset.symbol)"])],
            sortDescriptors: []
        ) { [weak self] result in
            switch result {
            case let .success(availableChainAssets):
                self?.output?.didReceiveChainAssets(availableChainAssets)
                self?.availableChainAssets = availableChainAssets
                self?.setupSubscriptions(chainAssets: availableChainAssets)
            default:
                self?.availableChainAssets = []
            }
        }
    }

    private func setupSubscriptions(chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: .main
        )
    }
}

extension AssetNetworksInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension AssetNetworksInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        output?.didReceiveChainsWithIssues(issues)
    }
}
