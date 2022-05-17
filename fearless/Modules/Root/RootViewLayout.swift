import UIKit

class RootViewLayout: UIView {
    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let fearlessLogoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.logo()
        return imageView
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {}

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundImageView)
        addSubview(fearlessLogoImageView)

        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        fearlessLogoImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
