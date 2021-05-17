import UIKit
import SoraUI

final class LearnMoreView: BackgroundedContentControl {
    let fearlessIconView: UIView = {
        let view = UIImageView(image: R.image.iconFearlessSmall())
        view.contentMode = .scaleAspectFit
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let arrowIconView: UIView = {
        let imageView = UIImageView(image: R.image.iconAboutArrow())
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let shapeView = ShapeView()
        shapeView.isUserInteractionEnabled = false
        shapeView.fillColor = .clear
        shapeView.highlightedFillColor = R.color.colorCellSelection()!
        backgroundView = shapeView

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: 48.0
        )
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [fearlessIconView, titleLabel, UIView(), arrowIconView])
        stackView.spacing = 12
        stackView.isUserInteractionEnabled = false

        contentView = stackView
    }
}
