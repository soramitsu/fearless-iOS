import Foundation

protocol SelectExportAccountViewModelFactoryProtocol {
    func buildViewModel(
        metaAccount: MetaAccountModel,
        nativeAccounts: [ChainAccountResponse]?,
        addedAccounts: [ChainAccountModel]?,
        chains: [ChainModel],
        locale: Locale
    ) -> SelectExportAccountViewModel

    func buildEmptyViewModel(metaAccount: MetaAccountModel, locale: Locale) -> SelectExportAccountViewModel
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
                .accountsWithOneKey(preferredLanguages: locale.rLanguages),
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
        metaAccount: MetaAccountModel,
        nativeAccounts: [ChainAccountResponse]?,
        addedAccounts: [ChainAccountModel]?,
        chains: [ChainModel],
        locale: Locale
    ) -> SelectExportAccountViewModel {
        SelectExportAccountViewModel(
            title: R.string.localizable
                .whatAccountsForExport(preferredLanguages: locale.rLanguages),
            metaAccountName: metaAccount.name,
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

    func buildEmptyViewModel(metaAccount: MetaAccountModel, locale: Locale) -> SelectExportAccountViewModel {
        SelectExportAccountViewModel(
            title: R.string.localizable.whatAccountsForExport(preferredLanguages: locale.rLanguages),
            metaAccountName: metaAccount.name,
            metaAccountBalanceString: nil,
            nativeAccountCellViewModel: nil,
            addedAccountsCellViewModels: nil
        )
    }
}
