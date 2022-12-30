import UIKit
import SoraUI

final class CheckPincodeViewLayout: UIView {
    enum Layout {
        static let titleLabelOffset: CGFloat = 20
        static let pinViewCenterVerticalOffset: CGFloat = 48
    }

    private let mainViewAccessibilityId: String? = "MainViewAccessibilityId"
    private let bgViewAccessibilityId: String? = "BgViewAccessibilityId"
    private let inputFieldAccessibilityId: String? = "InputFieldAccessibilityId"
    private let keyPrefixAccessibilityId: String? = "KeyPrefixAccessibilityId"
    private let backspaceAccessibilityId: String? = "BackspaceAccessibilityId"

    lazy var navigationBar: BaseNavigationBar = {
        let navBar = BaseNavigationBar()
        navBar.set(.present)
        return navBar
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let pinView: PinView = {
        let view = PinViewConfigurator.defaultPinView()
        view.numpadView?.accessoryIcon = view.numpadView?.accessoryIcon?.tinted(with: R.color.colorWhite()!)
        view.numpadView?.backspaceIcon = view.numpadView?.backspaceIcon?.tinted(with: R.color.colorWhite()!)
        return view
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black
        setupLayout()
        applyLocalization()
        setupAccessibilityIdentifiers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension CheckPincodeViewLayout {
    func applyLocalization() {
        titleLabel.text = R.string.localizable
            .pincodeEnterPinCode(preferredLanguages: locale.rLanguages)
        navigationTitleLabel.text = R.string.localizable
            .pincodeEnterPinCode(preferredLanguages: locale.rLanguages)
    }

    func setupLayout() {
        addSubview(navigationBar)
        addSubview(titleLabel)
        addSubview(pinView)

        navigationBar.setCenterViews([navigationTitleLabel])

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        pinView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(Layout.pinViewCenterVerticalOffset)
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.titleLabelOffset)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
        }
    }

    private func setupAccessibilityIdentifiers() {
        accessibilityIdentifier = mainViewAccessibilityId
        pinView.setupInputField(accessibilityId: inputFieldAccessibilityId)
        pinView.numpadView?.setupKeysAccessibilityIdWith(format: keyPrefixAccessibilityId)
        pinView.numpadView?.setupBackspace(accessibilityId: backspaceAccessibilityId)
    }
}
