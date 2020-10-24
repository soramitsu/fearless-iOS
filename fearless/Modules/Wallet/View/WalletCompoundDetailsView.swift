import Foundation
import CommonWallet
import SoraUI

final class WalletCompoundDetailsView: WalletFormItemView {
    var contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0) {
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
        CGSize(width: UIView.noIntrinsicMetric,
               height: 52.0 + contentInsets.top + contentInsets.bottom)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.delegate = self
        contentView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle

        bottomConstraint.constant = contentInsets.bottom
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
    }
}

extension WalletCompoundDetailsView: DetailsTriangularedViewDelegate {
    func detailsViewDidSelectAction(_ details: DetailsTriangularedView) {
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
        }
    }
}
