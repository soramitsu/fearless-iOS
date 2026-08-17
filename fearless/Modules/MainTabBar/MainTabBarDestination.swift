import UIKit

enum MainTabBarDestination: Int, CaseIterable {
    case portfolio
    case defi
    case polkaswap
    case crossChain
    case settings

    var title: String {
        switch self {
        case .portfolio:
            return NSLocalizedString("tab.portfolio", value: "Portfolio", comment: "")
        case .defi:
            return NSLocalizedString("tab.defi", value: "DeFi", comment: "")
        case .polkaswap:
            return NSLocalizedString("tab.polkaswap", value: "Polkaswap", comment: "")
        case .crossChain:
            return NSLocalizedString("tab.cross_chain", value: "Cross-chain", comment: "")
        case .settings:
            return NSLocalizedString("tab.settings", value: "Settings", comment: "")
        }
    }

    var image: UIImage? {
        switch self {
        case .portfolio:
            return R.image.iconTabWallet()
        case .defi:
            return R.image.iconTabStaking()
        case .polkaswap:
            return R.image.iconTabPolkaswap()
        case .crossChain:
            return R.image.crossChainIcon()
        case .settings:
            return R.image.iconTabSettings()
        }
    }
}
