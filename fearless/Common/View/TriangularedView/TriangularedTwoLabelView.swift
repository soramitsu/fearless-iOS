import UIKit

@IBDesignable
final class TriangularedTwoLabelView: TriangularedView {
    let twoVerticalLabelView = TwoVerticalLabelView()
    var contentInsets = UIEdgeInsets(top: 8.0, left: 16, bottom: 8.0, right: 16) {
        didSet {
            invalidateLayout()
        }
    }

    override func configure() {
        super.configure()

        if twoVerticalLabelView.superview == nil {
            addSubview(twoVerticalLabelView)
        }
    }

    func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        let contentSize = twoVerticalLabelView.intrinsicContentSize

        return CGSize(
            width: contentSize.width + contentInsets.left + contentInsets.right,
            height: contentSize.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        twoVerticalLabelView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
        }
    }
}
