import Foundation
import RobinHood
import SoraFoundation
import SSFModels

struct ChainSelectionViewFactory {
    // swiftlint:disable function_parameter_count
    static func createView(
        delegate: ChainSelectionDelegate,
        selectedChainId: ChainModel.Id?,
        repositoryFilter: NSPredicate?,
        selectedMetaAccount: MetaAccountModel,
        includeAllNetworksCell: Bool,
        showBalances: Bool,
        chainModels: [ChainModel]?,
        assetSelectionType: AssetSelectionType
    ) -> ChainSelectionViewProtocol? {
        let repository = ChainRepositoryFactory().createRepository(
            for: repositoryFilter,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = ChainSelectionInteractor(
            selectedMetaAccount: selectedMetaAccount,
            repository: AnyDataProviderRepository(repository),
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedMetaAccount
            ),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            showBalances: showBalances,
            chainModels: chainModels
        )

        let wireframe = ChainSelectionWireframe()
        wireframe.delegate = delegate

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        let localizationManager = LocalizationManager.shared

        switch assetSelectionType {
        case .normal:
            let presenter = ChainSelectionPresenter(
                interactor: interactor,
                wireframe: wireframe,
                selectedChainId: selectedChainId,
                assetBalanceFormatterFactory: assetBalanceFormatterFactory,
                includeAllNetworksCell: includeAllNetworksCell,
                showBalances: showBalances,
                selectedMetaAccount: selectedMetaAccount,
                localizationManager: localizationManager
            )

            let title = LocalizableResource { locale in
                R.string.localizable.commonSelectNetwork(
                    preferredLanguages: locale.rLanguages
                )
            }

            let view = ChainSelectionViewController(
                nibName: R.nib.selectionListViewController.name,
                localizedTitle: title,
                presenter: presenter,
                localizationManager: localizationManager
            )

            presenter.view = view
            interactor.presenter = presenter

            return view
        case .staking:
            let presenter = ChainSelectionPresenter(
                interactor: interactor,
                wireframe: wireframe,
                selectedChainId: selectedChainId,
                assetBalanceFormatterFactory: assetBalanceFormatterFactory,
                includeAllNetworksCell: includeAllNetworksCell,
                showBalances: showBalances,
                selectedMetaAccount: selectedMetaAccount,
                localizationManager: localizationManager
            )

            let title = LocalizableResource { locale in
                R.string.localizable.commonSelectNetwork(
                    preferredLanguages: locale.rLanguages
                )
            }

            let view = StakingChainSelectionViewController(
                nibName: R.nib.selectionListViewController.name,
                localizedTitle: title,
                presenter: presenter,
                localizationManager: localizationManager
            )

            presenter.view = view
            interactor.presenter = presenter

            return view
        }
    }
}
