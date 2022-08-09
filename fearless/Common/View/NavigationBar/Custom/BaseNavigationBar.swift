import UIKit

class BaseNavigationBar: BaseTopBar {
    enum LayoutConstaints {
        static let backButtonWidth: CGFloat = 40
    }

    enum NavigationStyle {
        case push
        case present
    }

    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        button.layer.masksToBounds = true
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = .white
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black.withAlphaComponent(0.4)
    }

    override func layoutIfNeeded() {
        super.layoutIfNeeded()

        backButton.layer.cornerRadius = backButton.frame.size.height / 2
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        backButton.layer.cornerRadius = backButton.frame.size.height / 2
    }

    override func setupLayout() {
        super.setupLayout()

        setLeftViews([backButton])

        backButton.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 32, height: 32))
        }
    }

    func set(_ style: NavigationStyle) {
        switch style {
        case .push:
            backButton.setImage(R.image.iconBack(), for: .normal)
        case .present:
            backButton.setImage(R.image.iconClose(), for: .normal)
        }
    }

    func setTitle(_ title: String) {
        setCenterViews([titleLabel])
        titleLabel.text = title
    }
}
