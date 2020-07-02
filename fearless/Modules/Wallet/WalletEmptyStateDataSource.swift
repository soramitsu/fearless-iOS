import UIKit
import SoraUI
import SoraFoundation

final class WalletEmptyStateDataSource {
    var titleResource: LocalizableResource<String>?
    var imageForEmptyState: UIImage?
    var titleColorForEmptyState: UIColor? = UIColor.emptyStateTitle
    var titleFontForEmptyState: UIFont? = UIFont.emptyStateTitle
    var verticalSpacingForEmptyState: CGFloat? = 16.0
    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy = .none

    init(titleResource: LocalizableResource<String>, image: UIImage? = nil) {
        self.titleResource = titleResource
        self.imageForEmptyState = image
    }
}

extension WalletEmptyStateDataSource: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        return nil
    }

    var titleForEmptyState: String? {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        return titleResource?.value(for: locale)
    }
}

extension WalletEmptyStateDataSource: Localizable {
    func applyLocalization() {}
}
