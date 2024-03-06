import UIKit

class BaseNavigationBar: BaseTopBar {
    enum LayoutConstants {
        static let backButtonSize: CGFloat = 32
    }

    enum NavigationStyle {
        case push
        case present
    }

    enum BackButtonAlignment {
        case left
        case right
    }

    let indicator: UIView = {
        UIFactory.default.createIndicatorView()
    }()

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
        label.textColor = R.color.colorWhite()
        return label
    }()

    var backButtonAlignment: BackButtonAlignment = .left

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack19()
    }

    override func setupLayout() {
        super.setupLayout()

        switch backButtonAlignment {
        case .left:
            setLeftViews([backButton])
        case .right:
            setRightViews([backButton])
        }

        backButton.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.backButtonSize)
        }

        addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.size.equalTo(UIConstants.indicatorSize)
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
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
