import UIKit

final class LearnMoreView: UIView {
    let fearlessIconView: UIView = UIImageView(image: R.image.iconFearlessSmall())

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
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [fearlessIconView, titleLabel, UIView(), arrowIconView])
        stackView.spacing = 12
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.top.equalToSuperview().inset(16)
        }
    }
}
