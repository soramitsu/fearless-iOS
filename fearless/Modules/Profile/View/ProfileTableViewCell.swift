import UIKit
import SoraUI

final class ProfileTableViewCell: UITableViewCell {
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var iconSmallArrow: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet var switcher: UISwitch!
    @IBOutlet var accessoryImageView: UIImageView!
    private(set) var viewModel: ProfileOptionViewModelProtocol?
    /// Sun-lit row: a Raised-1 pill that sinks while pressed.
    private let surface: FWNeuView = {
        let view = FWNeuView()
        view.style = .raised1
        view.isInteractive = true
        view.isUserInteractionEnabled = false
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: FWSunlit.Radius.row) }
        return view
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = .clear
        self.selectedBackgroundView = selectedBackgroundView
        clipsToBounds = false
        contentView.clipsToBounds = false
        let borders = contentView.subviews.compactMap { $0 as? BorderedContainerView }
        if let container = borders.first {
            container.backgroundColor = .clear
            container.strokeColor = .clear
            contentView.insertSubview(surface, at: 0)
            surface.snp.makeConstraints { make in
                make.leading.trailing.equalTo(container)
                make.top.bottom.equalTo(container).inset(4)
            }
            padContentInsidePill(container: container)
        }
        titleLabel.textColor = FWSunlit.Palette.textPrimary
        subtitleLabel.textColor = FWSunlit.Palette.textSecondary
        iconSmallArrow.tintColor = FWSunlit.Palette.textTertiary
        switcher.onTintColor = FWSunlit.Palette.brand
    }

    /// The nib places the icon and arrow 4 pt inside the row's container, which is now the pill's edge; they
    /// move in to the pill's 14 pt padding, and the switch to 12 pt.
    private func padContentInsidePill(container: UIView) {
        for constraint in contentView.constraints {
            if constraint.firstItem === iconImageView, constraint.firstAttribute == .leading {
                constraint.constant = 30
            }
            if constraint.secondItem === iconSmallArrow, constraint.secondAttribute == .trailing {
                constraint.constant = 28
            }
        }
        for constraint in container.constraints
            where constraint.secondItem === switcher && constraint.secondAttribute == .trailing {
            constraint.constant = 4
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        surface.setPressed(highlighted, animated: animated)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconSmallArrow.isHidden = false
        subtitleLabel.isHidden = false
        switcher.isHidden = true
    }

    func bind(viewModel: ProfileOptionViewModelProtocol) {
        self.viewModel = viewModel

        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title

        subtitleLabel.text = viewModel.accessoryTitle

        accessoryImageView.isHidden = viewModel.accessoryImage == nil
        accessoryImageView.image = viewModel.accessoryImage

        guard case let .switcher(isOn) = viewModel.accessoryType else {
            switcher.isHidden = true
            return
        }

        iconSmallArrow.isHidden = true
        subtitleLabel.isHidden = true
        switcher.isHidden = false
        switcher.isOn = isOn
    }
}
