import UIKit

class BaseNavigationBar: BaseTopBar {
    enum LayoutConstaints {
        static let backButtonWidth: CGFloat = 40
    }

    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black.withAlphaComponent(0.4)
    }

    override func setupLayout() {
        super.setupLayout()

        setLeftViews([backButton])
    }
}
