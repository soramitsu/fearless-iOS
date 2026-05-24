import Foundation
import SSFModels
import FearlessSecureStorage

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
    private let eventCenter: EventCenterProtocol
    private let logger: LoggerProtocol?

    init(
        accountScoreFetcher: AccountStatisticsFetching,
        settings: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol = EventCenter.shared,
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.accountScoreFetcher = accountScoreFetcher
        self.settings = settings
        self.eventCenter = eventCenter
        self.logger = logger
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

        var address: String?
        if
            let selectedChain = selectedChain,
            let chainAccountResponse = selectedMetaAccount.fetch(for: selectedChain.accountRequest()),
            let address1 = try? AddressFactory.address(for: chainAccountResponse.accountId, chain: selectedChain) {
            address = address1
        }

        let ethAddress = selectedMetaAccount.ethereumAddress?.toHex(includePrefix: true)
        let accountScoreViewModel = AccountScoreViewModel(
            fetcher: accountScoreFetcher,
            address: ethAddress,
            chain: nil,
            settings: settings,
            eventCenter: eventCenter,
            logger: logger
        )

        return WalletMainContainerViewModel(
            walletName: selectedMetaAccount.name,
            selectedFilter: selectedFilterName,
            selectedFilterImage: selectedFilterImage,
            address: address,
            accountScoreViewModel: accountScoreViewModel
        )
    }
}
