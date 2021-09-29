import Foundation
import CommonWallet
import SoraUI

final class WalletCompoundDetailsView: WalletFormItemView {
    var contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0) {
        didSet {
            bottomConstraint.constant = contentInsets.bottom
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    @IBOutlet private var borderedView: BorderedContainerView!
    @IBOutlet private var contentView: DetailsTriangularedView!

    @IBOutlet private var bottomConstraint: NSLayoutConstraint!

    private var viewModel: WalletCompoundDetailsViewModel?

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: 52.0 + contentInsets.top + contentInsets.bottom
        )
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.addTarget(self, action: #selector(actionDetails), for: .touchUpInside)

        contentView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle

        bottomConstraint.constant = contentInsets.bottom
    }

    private func setupContentInsets() {
        contentInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 12.0, right: 0.0)
    }

    func bind(viewModel: WalletCompoundDetailsViewModel) {
        self.viewModel = viewModel

        contentView.title = viewModel.title
        contentView.subtitle = viewModel.details

        if let mainIcon = viewModel.mainIcon {
            contentView.iconRadius = max(mainIcon.size.width, mainIcon.size.height) / 2.0
            contentView.horizontalSpacing = 4.0
            contentView.iconImage = mainIcon
        } else {
            contentView.iconRadius = 0.0
            contentView.horizontalSpacing = 0.0
            contentView.iconImage = nil
        }

        contentView.actionImage = viewModel.actionIcon

        if viewModel.enabled {
            contentView.fillColor = .clear
            contentView.strokeColor = R.color.colorGray()!
            contentView.highlightedStrokeColor = R.color.colorGray()!
            contentView.highlightedFillColor = R.color.colorHighlightedPink()!
        } else {
            contentView.fillColor = R.color.colorDarkGray()!
            contentView.strokeColor = R.color.colorDarkGray()!
            contentView.highlightedStrokeColor = R.color.colorDarkGray()!
            contentView.highlightedFillColor = R.color.colorHighlightedPink()!
        }
    }

    @objc private func actionDetails() {
        try? viewModel?.command.execute()
    }
}

extension WalletCompoundDetailsView {
    var borderType: BorderType {
        get {
            borderedView.borderType
        }

        set {
            borderedView.borderType = newValue
            setupContentInsets()
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }
}

extension WalletCompoundDetailsView: ReceiverViewProtocol {
    func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        guard let viewModel = viewModel as? WalletCompoundDetailsViewModel else {
            return
        }

        bind(viewModel: viewModel)
    }
}
