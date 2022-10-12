import UIKit
import SoraUI

final class ScanQRViewLayout: UIView {
    private enum Constants {
        static let titleTopOffset: CGFloat = 64
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = R.color.colorWhite8()
        bar.backButton.rounded()
        bar.backgroundColor = R.color.colorBlack()
        return bar
    }()

    let addButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconAddSquare(), for: .normal)
        return button
    }()

    let qrFrameView = CameraFrameView()

    let titleLabel: UILabel = {
        let label = UILabel()
        return label
    }()

    let messageLabel: UILabel = {
        let label = UILabel()
        return label
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {
        navigationBar.setTitle(
            R.string.localizable.contactsScan(preferredLanguages: locale.rLanguages)
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

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.layer.cornerRadius = navigationBar.backButton.frame.size.height / 2
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

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(Constants.titleTopOffset)
        }

        addSubview(messageLabel)
        messageLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-UIConstants.bigOffset)
            make.centerX.equalToSuperview()
        }
    }
}
