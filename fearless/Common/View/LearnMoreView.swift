import UIKit
import SoraUI
import SnapKit

final class LearnMoreView: BackgroundedContentControl {
    private enum Constants {
        static let iconSize: CGFloat = 24.0
        static let horizontalSpacing: CGFloat = 12.0
    }

    let iconView: UIImageView = {
        let view = UIImageView()
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

    deinit {
        viewModel?.iconViewModel?.cancel(on: iconView)
    }

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

        let iconSize = CGSize(width: Constants.iconSize, height: Constants.iconSize)
        viewModel?.iconViewModel?.loadImage(on: iconView, targetSize: iconSize, animated: true)
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
        let baseView = UIView()
        baseView.isUserInteractionEnabled = false

        baseView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        baseView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.horizontalSpacing)
            make.centerY.equalToSuperview()
        }

        baseView.addSubview(arrowIconView)
        arrowIconView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Constants.horizontalSpacing)
            make.size.equalTo(16.0)
        }

        contentView = baseView
    }
}
