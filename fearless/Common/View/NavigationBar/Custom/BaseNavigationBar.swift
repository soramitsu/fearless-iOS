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

    override func setupLayout() {
        super.setupLayout()

        setLeftViews([backButton])
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
