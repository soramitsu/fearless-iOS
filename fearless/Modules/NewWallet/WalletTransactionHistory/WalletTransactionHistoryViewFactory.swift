import Foundation
import SSFUtils
import RobinHood
import FearlessFoundation
import SSFModels

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
        let localizationManager = LocalizationManager.shared
        let dependencyContainer = WalletTransactionHistoryDependencyContainer(
            selectedAccount: selectedAccount,
            localizationManager: localizationManager
        )

        let interactor = WalletTransactionHistoryInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            dependencyContainer: dependencyContainer,
            logger: Logger.shared,
            defaultFilter: WalletHistoryRequest(assets: [asset.id]),
            selectedFilter: WalletHistoryRequest(assets: [asset.id]),
            filters: transactionHistoryFilters(
                for: chain,
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ),
            eventCenter: EventCenter.shared,
            applicationHandler: ApplicationHandler()
        )
        let wireframe = WalletTransactionHistoryWireframe()

        let viewModelFactory = WalletTransactionHistoryViewModelFactory(
            balanceFormatterFactory: AssetBalanceFormatterFactory(),
            includesFeeInAmount: false,
            transactionTypes: [.incoming, .outgoing],
            chainAsset: ChainAsset(chain: chain, asset: asset),
            iconGenerator: UniversalIconGenerator()
        )

        let presenter = WalletTransactionHistoryPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            logger: Logger.shared,
            localizationManager: localizationManager
        )

        let view = WalletTransactionHistoryViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return WalletTransactionHistoryModule(view: view, moduleInput: presenter)
    }

    // swiftlint:disable:next function_body_length
    static func transactionHistoryFilters(
        for chain: ChainModel,
        preferredLanguages: [String]? = nil
    ) -> [FilterSet] {
        guard let history = chain.externalApi?.history else {
            return []
        }
        let explorerType = history.type
        guard explorerType.hasFilters else {
            return []
        }

        var filters: [WalletTransactionHistoryFilter] = [
            WalletTransactionHistoryFilter(
                type: .transfer,
                selected: true,
                preferredLanguages: preferredLanguages
            )
        ]
        if explorerType != .giantsquid {
            filters.insert(
                WalletTransactionHistoryFilter(
                    type: .other,
                    selected: true,
                    preferredLanguages: preferredLanguages
                ),
                at: 1
            )
        }
        if chain.hasStakingRewardHistory || chain.isSora {
            filters.insert(
                WalletTransactionHistoryFilter(
                    type: .reward,
                    selected: true,
                    preferredLanguages: preferredLanguages
                ),
                at: 1
            )
        }
        if chain.hasPolkaswap {
            filters.insert(
                WalletTransactionHistoryFilter(
                    type: .swap,
                    selected: true,
                    preferredLanguages: preferredLanguages
                ),
                at: 0
            )
            filters.removeAll(where: { $0.type == .other })
        }

        return [FilterSet(
            title: R.string.localizable.commonShow(
                preferredLanguages: preferredLanguages
            ),
            items: filters
        )]
    }

    private static func createHistoryDeps(
        for chain: ChainModel
    ) -> (HistoryServiceProtocol, HistoryDataProviderFactoryProtocol)? {
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        guard
            let operationFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
                chain: chain,
                txStorage: AnyDataProviderRepository(txStorage)
            )
        else {
            return nil
        }

        let dataProviderFactory = HistoryDataProviderFactory(
            operationFactory: operationFactory
        )

        let service = HistoryService(operationFactory: operationFactory, operationQueue: OperationQueue())
        return (service, dataProviderFactory)
    }
}
