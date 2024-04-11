import Foundation
import SoraKeystore
import RobinHood
import SSFModels

enum AssetManagementMigratorError: Error {
    case walletNotExist
}

// MARK: - AssetManagementMigrator

final class AssetManagementMigrator: Migrating {
    private let userDefaultsStorage: SettingsManagerProtocol
    private let accountInfoFetchingProvider: AccountInfoFetching
    private let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let operationManager: OperationManagerProtocol

    init(
        userDefaultsStorage: SettingsManagerProtocol,
        accountInfoFetchingProvider: AccountInfoFetching,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainAssetFetching: ChainAssetFetchingProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.userDefaultsStorage = userDefaultsStorage
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.walletRepository = walletRepository
        self.chainAssetFetching = chainAssetFetching
        self.operationManager = operationManager
    }

    // MARK: - Migrating

    func migrate() throws {
        Task {
            let chainAssets = try await chainAssetFetching.fetchAwait(
                shouldUseCache: false,
                filters: [],
                sortDescriptors: []
            )

            let wallets = try await getWallets()

            try await wallets.asyncForEach { wallet in
                guard shouldMigrate(wallet: wallet) else {
                    return
                }

                let accountInfos = try await accountInfoFetchingProvider.fetchByUniqKey(
                    for: chainAssets,
                    wallet: wallet
                )

                let assetVisibilities = chainAssets.map {
                    let isOn = checkAssetIsOn(
                        chainAsset: $0,
                        accountInfos: accountInfos,
                        wallet: wallet
                    )
                    let visibility = AssetVisibility(
                        assetId: $0.identifier,
                        hidden: !isOn
                    )
                    return visibility
                }

                let updatedWallet = wallet.replacingAssetsVisibility(assetVisibilities)
                save(wallet: updatedWallet)

                migrated(wallet)
            }
        }
    }

    // MARK: - Private methods

    private func migrated(_ wallet: MetaAccountModel) {
        let isFirstRunKey = createKeyForFirstRunAssetManagement(wallet: wallet)
        userDefaultsStorage.set(value: true, for: isFirstRunKey)
    }

    private func save(wallet: MetaAccountModel) {
        let saveOperation = walletRepository.saveOperation {
            [wallet]
        } _: {
            []
        }

        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }

    private func shouldMigrate(wallet: MetaAccountModel) -> Bool {
        guard wallet.assetsVisibility.isNotEmpty else {
            migrated(wallet)
            return false
        }
        let shouldMigrateKey = createKeyForFirstRunAssetManagement(wallet: wallet)
        let shouldMigrate = userDefaultsStorage.bool(for: shouldMigrateKey) == nil
        return shouldMigrate
    }

    private func getWallets() async throws -> [MetaAccountModel] {
        let fetchAllOperation = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())
        operationManager.enqueue(operations: [fetchAllOperation], in: .transient)

        return try await withCheckedThrowingContinuation { continuation in
            fetchAllOperation.completionBlock = {
                do {
                    let wallets = try fetchAllOperation.extractNoCancellableResultData()
                    continuation.resume(returning: wallets)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func checkAssetIsOn(
        chainAsset: ChainAsset,
        accountInfos: [ChainAssetKey: AccountInfo?],
        wallet: MetaAccountModel
    ) -> Bool {
        let request = chainAsset.chain.accountRequest()
        guard let accountId = wallet.fetch(for: request)?.accountId else {
            return false
        }
        let key = chainAsset.uniqueKey(accountId: accountId)
        guard let accountInfo = accountInfos[key] else {
            return false
        }

        return accountInfo?.nonZero() == true
    }

    private func createKeyForFirstRunAssetManagement(
        wallet: MetaAccountModel
    ) -> String {
        [
            "asset.management.should.migrate.wallet",
            wallet.metaId
        ].joined(separator: ":")
    }
}

// MARK: - AssetManagementMigratorAssembly

enum AssetManagementMigratorAssembly {
    static func createDefaultMigrator() -> Migrating {
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )
        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let accountInfoFetchingProvider = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let walletRepository = AccountRepositoryFactory.createRepository()

        let chainRepository = ChainRepositoryFactory().createRepository()
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let migrator = AssetManagementMigrator(
            userDefaultsStorage: SettingsManager.shared,
            accountInfoFetchingProvider: accountInfoFetchingProvider,
            walletRepository: walletRepository,
            chainAssetFetching: chainAssetFetching,
            operationManager: OperationManagerFacade.sharedManager
        )

        return migrator
    }
}
