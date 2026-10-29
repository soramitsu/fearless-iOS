import UIKit

enum MainTabBarDestination: Int, CaseIterable {
    case portfolio
    case defi
    case polkaswap
    case crossChain
    case settings

    /// Stable identifier of the destination's tab in the iPad sidebar and tab bar.
    var tabIdentifier: String {
        "fearless.tab.\(self)"
    }

    init?(tabIdentifier: String) {
        guard let destination = Self.allCases.first(where: { $0.tabIdentifier == tabIdentifier }) else {
            return nil
        }
        self = destination
    }

    var title: String {
        switch self {
        case .portfolio:
            return NSLocalizedString("tab.portfolio", value: "Wallet", comment: "")
        case .defi:
            return NSLocalizedString("tab.defi", value: "Earn", comment: "")
        case .polkaswap:
            return NSLocalizedString("tab.polkaswap", value: "Swap", comment: "")
        case .crossChain:
            return NSLocalizedString("tab.cross_chain", value: "Transfer", comment: "")
        case .settings:
            // No language has a tab.settings entry; the Settings screen title is translated everywhere.
            return NSLocalizedString(
                "tab.settings",
                value: NSLocalizedString("profile.title", value: "Settings", comment: ""),
                comment: ""
            )
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
