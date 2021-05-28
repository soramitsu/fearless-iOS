import UIKit
import SoraUI
import SnapKit

final class LearnMoreView: BackgroundedContentControl {
    let iconView: UIImageView = {
        let view = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 24.0, height: 24.0)))
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

    private var viewModel: LearnMoreViewModel?

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

    func bind(viewModel: LearnMoreViewModel?) {
        self.viewModel?.iconViewModel?.cancel(on: iconView)
        iconView.image = nil

        self.viewModel = viewModel

        viewModel?.iconViewModel?.loadImage(on: iconView, targetSize: iconView.frame.size, animated: true)
        titleLabel.text = viewModel?.title
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY + contentInsets.top,
            width: bounds.width - contentInsets.left - contentInsets.right,
            height: bounds.height - contentInsets.top - contentInsets.bottom
        )
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: 48.0
        )
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), arrowIconView])
        stackView.spacing = 12
        stackView.isUserInteractionEnabled = false

        contentView = stackView
    }
}
