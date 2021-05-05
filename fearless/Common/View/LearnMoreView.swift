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
        let stackView = UIStackView(arrangedSubviews: [fearlessIconView, titleLabel, UIView(), arrowIconView])
        stackView.spacing = 12
        addSubview(stackView)
        stackView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}
