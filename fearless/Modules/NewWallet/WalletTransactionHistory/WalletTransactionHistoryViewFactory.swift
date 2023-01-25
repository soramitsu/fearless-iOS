import Foundation
import FearlessUtils
import CommonWallet
import RobinHood
import SoraFoundation

struct WalletTransactionHistoryModule {
    let view: WalletTransactionHistoryViewProtocol?
    let moduleInput: WalletTransactionHistoryModuleInput?
}

enum WalletTransactionHistoryViewFactory {
    static func createView(
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) -> WalletTransactionHistoryModule? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
              let historyOperationFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
                  chainAsset: chainAsset,
                  txStorage: AnyDataProviderRepository(txStorage),
                  runtimeService: runtimeService
              ) else {
            return nil
        }

        let dataProviderFactory = HistoryDataProviderFactory(
            cacheFacade: SubstrateDataStorageFacade.shared,
            operationFactory: historyOperationFactory
        )
        let service = HistoryService(
            operationFactory: historyOperationFactory,
            operationQueue: OperationQueue()
        )

        let interactor = WalletTransactionHistoryInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            dataProviderFactory: dataProviderFactory,
            historyService: service,
            logger: Logger.shared,
            defaultFilter: WalletHistoryRequest(assets: [asset.identifier]),
            selectedFilter: WalletHistoryRequest(assets: [asset.identifier]),
            filters: transactionHistoryFilters(for: chain),
            eventCenter: EventCenter.shared,
            applicationHandler: ApplicationHandler()
        )
        let wireframe = WalletTransactionHistoryWireframe()

        let viewModelFactory = WalletTransactionHistoryViewModelFactory(
            balanceFormatterFactory: AssetBalanceFormatterFactory(),
            includesFeeInAmount: false,
            transactionTypes: [.incoming, .outgoing],
            chainAsset: ChainAsset(chain: chain, asset: asset),
            iconGenerator: PolkadotIconGenerator()
        )

        let presenter = WalletTransactionHistoryPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chain: chain,
            asset: asset,
            localizationManager: LocalizationManager.shared
        )

        let view = WalletTransactionHistoryViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return WalletTransactionHistoryModule(view: view, moduleInput: presenter)
    }

    static func transactionHistoryFilters(for chain: ChainModel) -> [FilterSet] {
        var filters: [WalletTransactionHistoryFilter] = [
            WalletTransactionHistoryFilter(type: .transfer, selected: true),
            WalletTransactionHistoryFilter(type: .other, selected: true)
        ]
        if chain.hasStakingRewardHistory {
            filters.insert(WalletTransactionHistoryFilter(type: .reward, selected: true), at: 1)
        }

        return [FilterSet(
            title: R.string.localizable.walletFiltersHeader(
                preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
            ),
            items: filters
        )]
    }
}
