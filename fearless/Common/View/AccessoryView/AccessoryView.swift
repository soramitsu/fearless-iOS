import UIKit
import SoraUI

protocol AccessoryViewProtocol: class {
    var contentView: UIView { get }
    var isActionEnabled: Bool { get set }

    var title: String? { get set }
    var titleView: UIView? { get set }
    var actionTitle: String? { get set }
}

final class AccessoryView: UIView, AccessoryViewProtocol {
    private struct Constants {
        static let titleLeadingMargin: CGFloat = 20.0
        static let titleTrallingMargin: CGFloat = 20.0
    }

    @IBOutlet private(set) var actionButton: RoundedButton!

    var contentView: UIView {
        return self
    }

    var isActionEnabled: Bool {
        get {
            return actionButton.isEnabled
        }

        set {
            return actionButton.isEnabled = newValue
        }
    }

    var actionTitle: String? {
        set {
            actionButton.imageWithTitleView?.title = newValue
            actionButton.invalidateLayout()

            setNeedsLayout()
        }

        get {
            return actionButton.imageWithTitleView?.title
        }
    }

    var titleColor: UIColor? {
        didSet {
            if let titleLabel = titleView as? UILabel {
                titleLabel.textColor = titleColor
            }
        }
    }

    var titleFont: UIFont? {
        didSet {
            if let titleLabel = titleView as? UILabel {
                titleLabel.font = titleFont
            }
        }
    }

    var minimumTitleScaleFactor: CGFloat = 0.75 {
        didSet {
            if let titleLabel = titleView as? UILabel {
                titleLabel.minimumScaleFactor = minimumTitleScaleFactor
            }
        }
    }

    var title: String? {
        set {
            if let titleLabel = titleView as? UILabel {
                titleLabel.text = newValue
            } else if let newTitle = newValue {
                setupTitleLabel(for: newTitle)
            }
        }

        get {
            if let titleLabel = titleView as? UILabel {
                return titleLabel.text
            } else {
                return nil
            }
        }
    }

    var titleView: UIView? {
        didSet {
            handleTitleViewChange(from: oldValue)
        }
    }

    private func handleTitleViewChange(from oldTitleView: UIView?) {
        oldTitleView?.removeFromSuperview()

        if let currentTitleView = titleView {
            addSubview(currentTitleView)

            configureTitleLayout()
        }
    }

    private func configureTitleLayout() {
        if let currentTitleView = titleView {
            currentTitleView.translatesAutoresizingMaskIntoConstraints = false

            currentTitleView.leadingAnchor
                .constraint(equalTo: leadingAnchor,
                            constant: Constants.titleLeadingMargin).isActive = true

            currentTitleView.centerYAnchor.constraint(equalTo: centerYAnchor,
                                                      constant: 0.0).isActive = true

            if currentTitleView is UILabel {
                currentTitleView.trailingAnchor
                    .constraint(equalTo: actionButton.leadingAnchor,
                                constant: -Constants.titleTrallingMargin).isActive = true
            }
        }
    }

    private func setupTitleLabel(for title: String) {
        let titleLabel = UILabel()
        titleLabel.numberOfLines = 2
        titleLabel.backgroundColor = .clear
        titleLabel.text = title
        titleLabel.textColor = titleColor
        titleLabel.font = titleFont
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = minimumTitleScaleFactor
        self.titleView = titleLabel
    }
}
