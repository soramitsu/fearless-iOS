import UIKit
import SoraUI

class BaseRowView: BackgroundedContentControl {
    let separatorView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.borderType = .bottom
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorDarkGray()!
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentInsets = UIEdgeInsets(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )

        let shapeView = ShapeView()
        shapeView.isUserInteractionEnabled = false
        shapeView.fillColor = .clear
        shapeView.highlightedFillColor = R.color.colorCellSelection()!
        backgroundView = shapeView

        let baseView = UIView()
        baseView.isUserInteractionEnabled = false

        baseView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }

        contentView = baseView
        baseView.autoresizingMask = [.flexibleWidth]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY + contentInsets.top,
            width: max(bounds.width - contentInsets.left - contentInsets.right, 0),
            height: max(bounds.height - contentInsets.top - contentInsets.bottom, 0)
        )
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: 48.0
        )
    }
}
