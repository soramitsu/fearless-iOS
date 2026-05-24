import Foundation
import FearlessFoundation

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

        func title(preferredLanguages: [String]?) -> String {
            switch self {
            case .spam:
                return R.string.localizable.nftsFiltersSpam(
                    preferredLanguages: preferredLanguages
                )
            case .airdrop:
                return R.string.localizable.nftsFiltersAirdrop(
                    preferredLanguages: preferredLanguages
                )
            }
        }
    }

    var type: NftFilterType
    var id: String
    var title: String
    var selected: Bool

    init(
        type: NftFilterType,
        selected: Bool = false,
        preferredLanguages: [String]? = nil
    ) {
        self.type = type
        self.selected = selected
        id = type.id
        title = type.title(preferredLanguages: preferredLanguages)
    }

    mutating func reset() {
        selected = true
    }

    static func defaultFilters(preferredLanguages: [String]? = nil) -> [NftCollectionFilter] {
        [NftCollectionFilter(type: .spam, selected: true, preferredLanguages: preferredLanguages),
         NftCollectionFilter(type: .airdrop, selected: false, preferredLanguages: preferredLanguages)]
    }
}

extension NftCollectionFilter: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.type == rhs.type &&
            lhs.id == rhs.id &&
            lhs.title == rhs.title &&
            lhs.selected == rhs.selected
    }
}
