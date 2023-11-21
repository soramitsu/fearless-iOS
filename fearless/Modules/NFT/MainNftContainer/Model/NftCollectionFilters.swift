import Foundation
import SoraFoundation

struct NftCollectionFilter: SwitchFilterItem {
    enum NftFilterType: String {
        case spam
        case airdrop

        var id: String {
            switch self {
            case .spam:
                return "SPAM"
            case .airdrop:
                return "AIRDROPS"
            }
        }

        var title: String {
            switch self {
            case .spam:
                return R.string.localizable.nftsFiltersSpam(
                    preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
                )
            case .airdrop:
                return R.string.localizable.nftsFiltersAirdrop(
                    preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
                )
            }
        }
    }

    var type: NftFilterType
    var id: String
    var title: String
    var selected: Bool

    init(type: NftFilterType, selected: Bool = false) {
        self.type = type
        self.selected = selected
        id = type.id
        title = type.title
    }

    mutating func reset() {
        selected = true
    }

    static func defaultFilters() -> [NftCollectionFilter] {
        [NftCollectionFilter(type: .spam, selected: true),
         NftCollectionFilter(type: .airdrop, selected: false)]
    }
}
