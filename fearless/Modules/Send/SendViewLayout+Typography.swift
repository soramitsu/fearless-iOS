import UIKit

extension SendViewLayout {
    func updateTypography() {
        guard FWAppearance.sendPresentationRestyled else { return }
        navigationTitleLabel.font = .fw(.titleM, locale: locale, compatibleWith: traitCollection)
        navigationBar.configureSendTitle(navigationTitleLabel, in: contentView.stackView, traits: traitCollection)
        sendAllLabel.font = .fw(.bodyM, locale: locale, compatibleWith: traitCollection)
        crossNetworkButton.titleLabel?.font = .fw(.bodyM, locale: locale, compatibleWith: traitCollection)
        amountView.configureSendPresentation(locale: locale, traits: traitCollection)
        searchView.configureSendPresentation(locale: locale, traits: traitCollection)
        selectNetworkView.configureWrapping(locale: locale, compatibleWith: traitCollection, reservesAction: true)
        [feeView, tipView].forEach { $0.configureSendPresentation(locale: locale, traits: traitCollection) }
        for item in [actionButton, scanButton, historyButton] {
            item.configureWrappingTitle(locale: locale, compatibleWith: traitCollection)
        }
        setNeedsLayout()
    }
}

/// Retain native switch drawing while providing the minimum touch target in Send's reserved row.
final class SendAllSwitch: UISwitch {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard FWAppearance.sendPresentationRestyled else { return super.point(inside: point, with: event) }
        return bounds.insetBy(dx: 0, dy: -max(0, (44 - bounds.height) / 2)).contains(point)
    }
}
