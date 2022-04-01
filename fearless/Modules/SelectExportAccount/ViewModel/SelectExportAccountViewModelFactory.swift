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
        metaAccount _: MetaAccountModel,
        chains: [ChainModel],
        locale: Locale
    ) -> SelectExportAccountCellViewModel? {
        guard let nativeAccounts = nativeAccounts else {
            return nil
        }

        let chainName = chains.first(where: { $0.isPolkadotOrKusama })?.name ?? ""
        return SelectExportAccountCellViewModel(title: R.string.localizable.accountsWithOneKey(preferredLanguages: locale.rLanguages), subtitle: chainName, hint: "", imageViewModel: nil)
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
            title: R.string.localizable.whatAccountsForExport(preferredLanguages: locale.rLanguages),
            metaAccountName: metaAccount.name,
            metaAccountBalanceString: nil,
            nativeAccountCellViewModel: buildNativeAccountsCellViewModel(nativeAccounts: nativeAccounts, metaAccount: metaAccount, chains: chains, locale: locale),
            addedAccountsCellViewModels: buildAddedAccountCellViewModels(addedAccounts: addedAccounts, chains: chains, locale: locale)
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
