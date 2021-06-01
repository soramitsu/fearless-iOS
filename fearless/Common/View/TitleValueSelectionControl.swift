import UIKit
import SoraUI

final class TitleValueSelectionControl: BackgroundedContentControl {
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

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorAccent()
        return label
    }()

    let arrowIconView: UIView = {
        let imageView = UIImageView(image: R.image.iconSmallArrow())
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

    private func setupLayout() {
        let baseView = UIView()
        baseView.isUserInteractionEnabled = false

        baseView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(24.0)
        }

        baseView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.centerY.equalToSuperview()
        }

        baseView.addSubview(arrowIconView)
        arrowIconView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.size.equalTo(24.0)
        }

        baseView.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.trailing.equalTo(arrowIconView.snp.leading).offset(-8.0)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        contentView = baseView

        baseView.autoresizingMask = [.flexibleWidth]
    }
}
