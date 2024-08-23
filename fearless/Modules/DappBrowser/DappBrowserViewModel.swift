import Foundation

enum DappBrowserViewModel {
    case featured([DappBrowserFeaturedViewModel])
    case section(ListSection)

    struct ListSection {
        let header: DappBrowserSectionHeaderViewViewModel
        let list: [DappBrowserListCellViewModel]
        let dapps: [TonDapp]
    }

    var featured: [DappBrowserFeaturedViewModel]? {
        switch self {
        case let .featured(featured):
            return featured
        case .section:
            return nil
        }
    }
}
