import UIKit
import SoraUI

class RowView<T: UIView>: BackgroundedContentControl {
    var preferredHeight: CGFloat? {
        didSet {
            invalidateLayout()
        }
    }

    let borderView = UIFactory.default.createBorderedContainerView()

    init(contentView: T? = nil, preferredHeight: CGFloat? = nil) {
        self.preferredHeight = preferredHeight

        super.init(frame: .zero)

        self.contentView = contentView

        setupLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let contentHeight: CGFloat

        if let preferredHeight = preferredHeight {
            contentHeight = preferredHeight - contentInsets.top - contentInsets.bottom
        } else {
            contentHeight = contentView?.intrinsicContentSize.height ?? 0.0
        }

        contentView?.frame = CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY + contentInsets.top,
            width: max(bounds.width - contentInsets.left - contentInsets.right, 0),
            height: contentHeight
        )

        borderView.frame = CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY,
            width: max(bounds.width - contentInsets.left - contentInsets.right, 0),
            height: bounds.height
        )
    }

    override var intrinsicContentSize: CGSize {
        let height: CGFloat

        if let preferredHeight = preferredHeight {
            height = preferredHeight
        } else {
            let contentHeight = contentView?.intrinsicContentSize.height ?? UIView.noIntrinsicMetric
            height = contentHeight + contentInsets.bottom + contentInsets.top
        }

        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: height
        )
    }

    private func setupLayout() {
        contentInsets = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        let shapeView = ShapeView()
        shapeView.isUserInteractionEnabled = false
        shapeView.fillColor = .clear
        shapeView.highlightedFillColor = R.color.colorCellSelection()!
        backgroundView = shapeView

        borderView.isUserInteractionEnabled = false
        shapeView.addSubview(borderView)

        if contentView == nil {
            contentView = T()
        }

        contentView?.isUserInteractionEnabled = false
        contentView?.autoresizingMask = [.flexibleWidth]
    }
}
