import UIKit

final class LearnMoreView: UIView {
    let fearlessIconView: UIView = {
        let image = R.image.iconFearlessSmall()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorWhite()!)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .white
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let arrowIconView: UIView = UIImageView(image: R.image.iconAboutArrow())

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(fearlessIconView)
        fearlessIconView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(fearlessIconView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
        }

        addSubview(arrowIconView)
        arrowIconView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
            make.trailing.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
    }
}
