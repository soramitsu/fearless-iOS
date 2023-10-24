import Foundation
import SSFModels

protocol SelectExportAccountViewModelFactoryProtocol {
    func buildViewModel(
        managedMetaAccountModel: ManagedMetaAccountModel,
        nativeAccounts: [ChainAccountResponse]?,
        addedAccounts: [ChainAccountModel]?,
        chains: [ChainModel],
        locale: Locale
    ) -> SelectExportAccountViewModel

    func buildEmptyViewModel(
        managedMetaAccountModel: ManagedMetaAccountModel,
        locale: Locale
    ) -> SelectExportAccountViewModel
}

class SelectExportAccountViewModelFactory {
    private func buildNativeAccountsCellViewModel(
        nativeAccounts: [ChainAccountResponse]?,
        chains: [ChainModel],
        locale: Locale
    ) -> SelectExportAccountCellViewModel? {
        guard let nativeAccounts = nativeAccounts else {
            return nil
        }

        let hint = R.string.localizable
            .exportWalletChainsCount(
                nativeAccounts.count,
                preferredLanguages: locale.rLanguages
            )

        let polkadotOrKusama = chains.first(where: { $0.isPolkadotOrKusama })
        let chainName = polkadotOrKusama?.name ?? ""
        let imageViewModel = polkadotOrKusama?.icon.map {
            RemoteImageViewModel(url: $0)
        }

        return SelectExportAccountCellViewModel(
            title: R.string.localizable
                .accountsWithSharedSecret(preferredLanguages: locale.rLanguages),
            subtitle: chainName,
            hint: hint,
            imageViewModel: imageViewModel,
            isSelected: true
        )
    }

    private func buildAddedAccountCellViewModels(
        addedAccounts: [ChainAccountModel]?,
        chains: [ChainModel],
        locale _: Locale
    ) -> [SelectExportAccountCellViewModel]? {
        guard let addedAccounts = addedAccounts else {
            return nil
        }

        var accountsByChains: [ChainAccountModel: ChainModel] = [:]
        addedAccounts.forEach { chainAccount in
            if let chain = chains.first(where: { $0.chainId == chainAccount.chainId }) {
                accountsByChains[chainAccount] = chain
            }
        }

        // TODO: - Make when finish disign and flow for export added accounts
        return []
    }
}

extension SelectExportAccountViewModelFactory: SelectExportAccountViewModelFactoryProtocol {
    func buildViewModel(
        managedMetaAccountModel: ManagedMetaAccountModel,
        nativeAccounts: [ChainAccountResponse]?,
        addedAccounts: [ChainAccountModel]?,
        chains: [ChainModel],
        locale: Locale
    ) -> SelectExportAccountViewModel {
        SelectExportAccountViewModel(
            title: R.string.localizable
                .whatAccountsForExport(preferredLanguages: locale.rLanguages),
            metaAccountName: managedMetaAccountModel.info.name,
            metaAccountBalance: managedMetaAccountModel.balance,
            metaAccountBalanceString: nil,
            nativeAccountCellViewModel: buildNativeAccountsCellViewModel(
                nativeAccounts: nativeAccounts,
                chains: chains,
                locale: locale
            ),
            addedAccountsCellViewModels: buildAddedAccountCellViewModels(
                addedAccounts: addedAccounts,
                chains: chains,
                locale: locale
            )
        )
    }

    func buildEmptyViewModel(
        managedMetaAccountModel: ManagedMetaAccountModel,
        locale: Locale
    ) -> SelectExportAccountViewModel {
        SelectExportAccountViewModel(
            title: R.string.localizable.whatAccountsForExport(preferredLanguages: locale.rLanguages),
            metaAccountName: managedMetaAccountModel.info.name,
            metaAccountBalance: managedMetaAccountModel.balance,
            metaAccountBalanceString: nil,
            nativeAccountCellViewModel: nil,
            addedAccountsCellViewModels: nil
        )
    }
}
