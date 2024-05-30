import Foundation
import RobinHood
import SoraFoundation
import SSFModels

enum AssetSelectionType {
    case normal
    case staking
}

enum AssetSelectionViewFactory {
    static func createView(
        delegate: AssetSelectionDelegate,
        type: AssetSelectionStakingType,
        selectedMetaAccount: MetaAccountModel,
        assetFilter: @escaping AssetSelectionFilter,
        assetSelectionType: AssetSelectionType
    ) -> ChainSelectionViewProtocol? {
        let repository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
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
            showBalances: true,
            chainModels: nil
        )

        let wireframe = AssetSelectionWireframe()
        wireframe.delegate = delegate

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        let localizationManager = LocalizationManager.shared

        switch assetSelectionType {
        case .normal:
            let presenter = AssetSelectionPresenter(
                interactor: interactor,
                wireframe: wireframe,
                assetFilter: assetFilter,
                type: type,
                selectedMetaAccount: selectedMetaAccount,
                assetBalanceFormatterFactory: assetBalanceFormatterFactory,
                localizationManager: localizationManager
            )

            let title = LocalizableResource { locale in
                R.string.localizable.commonSelectAsset(preferredLanguages: locale.rLanguages)
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
            let presenter = StakingAssetSelectionPresenter(
                interactor: interactor,
                wireframe: wireframe,
                assetFilter: assetFilter,
                type: type,
                selectedMetaAccount: selectedMetaAccount,
                assetBalanceFormatterFactory: assetBalanceFormatterFactory,
                localizationManager: localizationManager
            )

            let title = LocalizableResource { locale in
                R.string.localizable.commonSelectAsset(preferredLanguages: locale.rLanguages)
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
