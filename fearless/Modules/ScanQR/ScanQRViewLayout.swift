import UIKit
import SoraUI

final class ScanQRViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = R.color.colorWhite8()
        bar.backButton.rounded()
        bar.backgroundColor = R.color.colorAlmostBlack()
        return bar
    }()

    let addButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconAddSquare(), for: .normal)
        return button
    }()

    let qrFrameView = CameraFrameView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {
        navigationBar.titleLabel.text = R.string.localizable.contactsScan(
            preferredLanguages: locale.rLanguages
        )
    }

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

    func setupLayout() {
        addSubview(navigationBar)
        navigationBar.setRightViews([addButton])
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        addSubview(qrFrameView)
        qrFrameView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
