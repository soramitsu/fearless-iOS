import SSFUtils
import SSFModels
import FearlessSecureStorage

protocol SendViewModelFactoryProtocol {
    func buildRecipientViewModel(
        address: String,
        isValid: Bool,
        canEditing: Bool
    ) -> RecipientViewModel
    func buildNetworkViewModel(chain: ChainModel, canEdit: Bool) -> SelectNetworkViewModel
    func buildAccountScoreViewModel(address: String?, chain: ChainModel) -> AccountScoreViewModel?
}

final class SendViewModelFactory: SendViewModelFactoryProtocol {
    private let iconGenerator: IconGenerating
    private let accountScoreFetcher: AccountStatisticsFetching
    private let settings: SettingsManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let logger: LoggerProtocol?

    init(
        iconGenerator: IconGenerating,
        accountScoreFetcher: AccountStatisticsFetching,
        settings: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol = EventCenter.shared,
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.iconGenerator = iconGenerator
        self.accountScoreFetcher = accountScoreFetcher
        self.settings = settings
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func buildRecipientViewModel(
        address: String,
        isValid: Bool,
        canEditing: Bool
    ) -> RecipientViewModel {
        RecipientViewModel(
            address: address,
            icon: try? iconGenerator.generateFromAddress(address),
            isValid: isValid,
            canEditing: canEditing
        )
    }

    func buildNetworkViewModel(chain: ChainModel, canEdit: Bool) -> SelectNetworkViewModel {
        let iconViewModel = chain.icon.map { RemoteImageViewModel(url: $0) }
        return SelectNetworkViewModel(
            chainName: chain.name,
            iconViewModel: iconViewModel,
            canEdit: canEdit
        )
    }

    func buildAccountScoreViewModel(address: String?, chain: ChainModel) -> AccountScoreViewModel? {
        AccountScoreViewModel(
            fetcher: accountScoreFetcher,
            address: address,
            chain: chain,
            settings: settings,
            eventCenter: eventCenter,
            logger: logger
        )
    }
}
