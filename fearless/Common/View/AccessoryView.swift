import Foundation
import SoraUI

public protocol AccessoryViewProtocol: AnyObject {
    var contentView: UIView { get }

    var isActionEnabled: Bool { get set }

    var extendsUnderSafeArea: Bool { get }

    func bind(viewModel: AccessoryViewModelProtocol)
}

public extension AccessoryViewProtocol {
    var extendsUnderSafeArea: Bool { false }
}

final class AccessoryView: UIView {
    private enum Constants {
        static let titleLeadingWithIcon: CGFloat = 45.0
        static let titleLeadingWithoutIcon: CGFloat = 0.0
    }

    @IBOutlet private(set) var borderView: BorderedContainerView!
    @IBOutlet private(set) var iconImageView: UIImageView!
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private var titleLeading: NSLayoutConstraint!
    @IBOutlet private(set) var actionButton: RoundedButton!

    private var viewModel: AccessoryViewModelProtocol?
}

extension AccessoryView: AccessoryViewProtocol {
    var contentView: UIView {
        self
    }

    var isActionEnabled: Bool {
        get {
            actionButton.isEnabled
        }

        set {
            let shouldAllowAction = viewModel?.shouldAllowAction ?? true

            if newValue, shouldAllowAction {
                actionButton.enable()
            } else {
                actionButton.disable()
            }
        }
    }

    func bind(viewModel: AccessoryViewModelProtocol) {
        iconImageView.image = viewModel.icon
        iconImageView.isHidden = (viewModel.icon == nil)

        titleLabel.text = viewModel.title
        titleLeading.constant = iconImageView.isHidden ? Constants.titleLeadingWithoutIcon
            : Constants.titleLeadingWithIcon
        titleLabel.numberOfLines = viewModel.numberOfLines

        actionButton.imageWithTitleView?.title = viewModel.action

        if viewModel.shouldAllowAction {
            actionButton.enable()
        } else {
            actionButton.disable()
        }

        actionButton.invalidateLayout()

        self.viewModel = viewModel

        setNeedsLayout()
    }
}
