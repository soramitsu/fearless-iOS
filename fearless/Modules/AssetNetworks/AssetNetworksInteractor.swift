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
    private let wallet: MetaAccountModel
    private let catalog: CanonicalTokenGroupCatalog

    private var availableChainAssets: [ChainAsset] = []

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter,
        chainsIssuesCenter: ChainsIssuesCenter,
        chainSettingsRepository: AsyncAnyRepository<ChainSettings>,
        catalog: CanonicalTokenGroupCatalog = .bundled
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.catalog = catalog
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
            filters: [.enabled(wallet: wallet)],
            sortDescriptors: []
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case let .success(assets):
                    let members = Self.availableAssets(for: self.chainAsset, among: assets, wallet: self.wallet, catalog: self.catalog)
                    self.availableChainAssets = members
                    self.output?.didReceiveChainAssets(members)
                    self.setupSubscriptions(chainAssets: members)
                default:
                    self.availableChainAssets = []
                    self.output?.didReceiveChainAssets([])
                    self.setupSubscriptions(chainAssets: [])
                }
            }
        }
    }

    static func availableAssets(
        for asset: ChainAsset,
        among assets: [ChainAsset],
        wallet: MetaAccountModel,
        catalog: CanonicalTokenGroupCatalog = .bundled,
        userDefaults: UserDefaults = .standard
    ) -> [ChainAsset] {
        let members: [ChainAsset]
        if let group = catalog.group(for: asset) {
            members = catalog.members(of: group, among: assets)
        } else {
            members = assets.filter { $0.assetKey == asset.assetKey }
        }
        var seen = Set<AssetKey>()
        return members.filter {
            !$0.chain.disabled && !(wallet.unusedChainIds ?? []).contains($0.chain.chainId) &&
                wallet.fetch(for: $0.chain.accountRequest()) != nil &&
                !PortfolioVisibilityContext.lacksAppOwnedAccount($0, wallet: wallet) &&
                AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: $0.assetKey, userDefaults: userDefaults) != .hidden &&
                seen.insert($0.assetKey).inserted
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
