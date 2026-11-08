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
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    let pinView: PinView = {
        let view = PinViewConfigurator.defaultPinView()
        view.numpadView?.accessoryIcon = view.numpadView?.accessoryIcon?.tinted(with: R.color.colorWhite()!)
        view.numpadView?.backspaceIcon = view.numpadView?.backspaceIcon?.tinted(with: R.color.colorWhite()!)
        return view
    }()

    /// Sun-lit scene: the badge lights the page; raised keys and dots that fill from the key light.
    lazy var sunlit = FWPinScreenSunlit(pinView: pinView)

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    /// Seconds left in a PIN lockout; the title shows the countdown instead of the prompt while it is set.
    var lockoutRemaining: TimeInterval? {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = FWSunlit.Palette.background
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
        if let lockoutRemaining = lockoutRemaining {
            titleLabel.text = R.string.localizable.pincodeLockoutMessage(
                PinLockoutCountdown.format(lockoutRemaining),
                preferredLanguages: locale.rLanguages
            )
        } else {
            titleLabel.text = R.string.localizable
                .pincodeEnterPinCode(preferredLanguages: locale.rLanguages)
        }
        navigationTitleLabel.text = R.string.localizable
            .pincodeEnterPinCode(preferredLanguages: locale.rLanguages)
    }

    func setupLayout() {
        sunlit.installLight(in: self)
        addSubview(navigationBar)
        addSubview(sunlit.badgeRow)
        addSubview(titleLabel)
        addSubview(pinView)
        pinView.numpadView?.keyRadius = 34
        sunlit.styler.apply()

        navigationBar.setCenterViews([navigationTitleLabel])

        navigationBar.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
        }

        pinView.snp.makeConstraints { make in
            make.centerX.equalTo(safeAreaLayoutGuide)
            make.centerY.equalToSuperview().offset(Layout.pinViewCenterVerticalOffset)
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.titleLabelOffset)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalTo(safeAreaLayoutGuide)
            make.leading.greaterThanOrEqualTo(safeAreaLayoutGuide).offset(UIConstants.horizontalInset)
        }

        sunlit.badgeRow.snp.makeConstraints { make in
            make.centerX.equalTo(safeAreaLayoutGuide)
            make.top.greaterThanOrEqualTo(navigationBar.snp.bottom).offset(8)
            make.bottom.equalTo(titleLabel.snp.top).offset(-16)
        }
    }

    private func setupAccessibilityIdentifiers() {
        accessibilityIdentifier = mainViewAccessibilityId
        pinView.setupInputField(accessibilityId: inputFieldAccessibilityId)
        pinView.numpadView?.setupKeysAccessibilityIdWith(format: keyPrefixAccessibilityId)
        pinView.numpadView?.setupBackspace(accessibilityId: backspaceAccessibilityId)
    }
}
