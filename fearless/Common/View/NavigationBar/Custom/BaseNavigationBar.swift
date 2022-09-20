import UIKit

class BaseNavigationBar: BaseTopBar {
    enum LayoutConstants {
        static let backButtonSize: CGFloat = 32
    }

    enum NavigationStyle {
        case push
        case present
    }

    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        button.layer.cornerRadius = LayoutConstants.backButtonSize / 2
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

        backgroundColor = R.color.colorBlack19()
    }

    override func setupLayout() {
        super.setupLayout()

        setLeftViews([backButton])

        backButton.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.backButtonSize)
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
