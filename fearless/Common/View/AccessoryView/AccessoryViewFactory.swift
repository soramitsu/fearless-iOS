import UIKit
import SoraUI

protocol AccessoryViewFactoryProtocol: class {
    static func createAccessoryView(target: Any?,
                                    completionSelector: Selector?) -> AccessoryViewProtocol
    static func createActionTitleView(with title: String,
                                      target: Any?,
                                      actionHandler: Selector?) -> RoundedButton
}

final class AccessoryViewFactory: AccessoryViewFactoryProtocol {
    static func createAccessoryView(target: Any?,
                                    completionSelector: Selector?) -> AccessoryViewProtocol {
        let view = R.nib.accessoryView(owner: nil)!

        view.titleColor = R.color.colorWhite()!
        view.titleFont = UIFont.p1Paragraph

        if let target = target, let selector = completionSelector {
            view.actionButton.addTarget(target, action: selector, for: .touchUpInside)
        }

        return view
    }

    static func createActionTitleView(with title: String,
                                      target: Any?,
                                      actionHandler: Selector?) -> RoundedButton {
        let actionButton = RoundedButton()
        actionButton.imageWithTitleView?.titleColor = R.color.colorWhite()!
        actionButton.imageWithTitleView?.titleFont = UIFont.p1Paragraph
        actionButton.imageWithTitleView?.title = title
        actionButton.roundedBackgroundView?.fillColor = .clear
        actionButton.roundedBackgroundView?.highlightedFillColor = .clear
        actionButton.roundedBackgroundView?.shadowOpacity = 0.0
        actionButton.contentInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 16.0)
        actionButton.changesContentOpacityWhenHighlighted = true

        if let target = target, let selector = actionHandler {
            actionButton.addTarget(target, action: selector, for: .touchUpInside)
        }

        return actionButton
    }
}
