import Foundation
import SSFModels
import SoraKeystore
import SSFCrypto

protocol WalletMainContainerViewModelFactoryProtocol {
    func buildViewModel(
        selectedFilter: NetworkManagmentFilter,
        selectedChains: [ChainModel],
        selectedMetaAccount: MetaAccountModel,
        locale: Locale
    ) -> WalletMainContainerViewModel
}

final class WalletMainContainerViewModelFactory: WalletMainContainerViewModelFactoryProtocol {
    private let accountScoreFetcher: AccountStatisticsFetching
    private let settings: SettingsManagerProtocol

    init(accountScoreFetcher: AccountStatisticsFetching, settings: SettingsManagerProtocol) {
        self.accountScoreFetcher = accountScoreFetcher
        self.settings = settings
    }

    func buildViewModel(
        selectedFilter: NetworkManagmentFilter,
        selectedChains: [ChainModel],
        selectedMetaAccount: MetaAccountModel,
        locale: Locale
    ) -> WalletMainContainerViewModel {
        var selectedChain: ChainModel?
        let selectedFilterName: String
        let selectedFilterImage: ImageViewModelProtocol?
        switch selectedFilter {
        case let .chain(id):
            selectedChain = selectedChains.first(where: { $0.chainId == id })
            selectedFilterName = selectedChain?.name ?? ""
            selectedFilterImage = selectedChain?.icon.map { RemoteImageViewModel(url: $0) }
        case .all:
            selectedFilterName = R.string.localizable.chainSelectionAllNetworks(
                preferredLanguages: locale.rLanguages
            )
            selectedFilterImage = selectedFilter.filterImage
        case .popular:
            selectedFilterName = R.string.localizable.networkManagementPopular(preferredLanguages: locale.rLanguages)
            selectedFilterImage = selectedFilter.filterImage
        case .favourite:
            selectedFilterName = R.string.localizable.networkManagmentFavourite(preferredLanguages: locale.rLanguages)
            selectedFilterImage = selectedFilter.filterImage
        }

        var chainAddress: String?
        if
            let selectedChain = selectedChain,
            let chainAccountResponse = selectedMetaAccount.fetch(for: selectedChain.accountRequest()),
            let address = try? AddressFactory.address(
                for: chainAccountResponse.accountId,
                chainFormat: selectedChain.chainFormat(bounceable: false)
            ) {
            chainAddress = address
        }

        let ethAddress = selectedMetaAccount.ecosystem.ethereumAddress?.toHex(includePrefix: true)
        let accountScoreViewModel = AccountScoreViewModel(
            fetcher: accountScoreFetcher,
            address: ethAddress,
            chain: nil,
            settings: settings,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )

        return WalletMainContainerViewModel(
            walletName: selectedMetaAccount.name,
            selectedFilter: selectedFilterName,
            selectedFilterImage: selectedFilterImage,
            address: chainAddress,
            accountScoreViewModel: accountScoreViewModel,
            walletIcon: selectedMetaAccount.icon(),
            isSelectableNetwork: selectedMetaAccount.ecosystem.isRegular
        )
    }
}
