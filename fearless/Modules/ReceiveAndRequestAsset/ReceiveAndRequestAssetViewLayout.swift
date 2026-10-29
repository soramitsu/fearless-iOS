import UIKit
import SnapKit

final class ReceiveAndRequestAssetViewLayout: UIView {
    private enum LayoutConstants {
        static let cornerRadius: CGFloat = 20.0
        static let headerHeight: CGFloat = 56.0
        static let qrImageSize: CGFloat = 240
        static let verticalOffset: CGFloat = 12
        static let infoIconSize: CGFloat = 12
        static let infoViewsOffset: CGFloat = 10
        static let noteLabelMaxHeight: CGFloat = 33
        static let segmentedControlHeight: CGFloat = 32
        static let animateDuration = 0.4
    }

    let navigationTitleLabel = UILabel()
    var keyboardAdoptableConstraint: Constraint?
    private var displayedModel: ReceiveAssetViewModel?
    private var adaptiveLayoutReady = false

    private let indicator = UIFactory.default.createIndicatorView()
    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = LayoutConstants.verticalOffset
        view.stackView.alignment = .center
        return view
    }()

    let segmentedControl = FWSegmentedControl()
    let amountView = SelectableAmountInputView(type: .send)
    let qrView = QRView()

    private let walletLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textAlignment = .center
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textAlignment = .center
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.textColor = R.color.colorWhite75()!
        return label
    }()

    let networkLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityIdentifier = "receive.network"
        return label
    }()

    let networkInstructionLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = R.color.colorWhite75()
        return label
    }()

    let copyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let shareButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue || FWAppearance.receivePresentationRestyled {
                applyLocale()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        segmentedControl.delegate = self
        if FWAppearance.receivePresentationRestyled { setupAdaptiveLayout() }
        if #available(iOS 17.0, *) {
            registerForTraitChanges(
                [UITraitPreferredContentSizeCategory.self, UITraitLegibilityWeight.self]
            ) { (view: ReceiveAndRequestAssetViewLayout, _: UITraitCollection) in
                view.updateTypography()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if FWAppearance.receivePresentationRestyled {
            navigationBar.configureSendTitle(navigationTitleLabel, in: contentView.stackView, traits: traitCollection)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        updateTypography()
    }

    func bind(viewModel: ReceiveAssetViewModel) {
        displayedModel = viewModel
        applyDisplayModel(viewModel)
    }

    private func applyDisplayModel(_ viewModel: ReceiveAssetViewModel) {
        let title = R.string.localizable.walletReceiveNavigationTitle(
            viewModel.asset, preferredLanguages: locale.rLanguages
        )
        if FWAppearance.receivePresentationRestyled {
            navigationTitleLabel.text = title
            navigationTitleLabel.accessibilityTraits = .header
        } else {
            navigationBar.setTitle(title)
        }
        networkLabel.text = "\(viewModel.asset) · \(viewModel.networkName)"
        let instruction: String
        if FWAppearance.receivePresentationRestyled {
            let path = Bundle.main.path(forResource: locale.rLanguages?.first ?? "en", ofType: "lproj")
                ?? Bundle.main.path(forResource: "en", ofType: "lproj")
            let bundle = path.flatMap(Bundle.init(path:)) ?? .main
            instruction = bundle.localizedString(
                forKey: "ux.receive_network_instruction",
                value: "Send only %@ on %@ to this address.", table: "Localizable"
            )
        } else {
            instruction = NSLocalizedString(
                "ux.receive_network_instruction",
                value: "Send only %@ on %@ to this address.", comment: "Asset and network"
            )
        }
        networkInstructionLabel.text = String(format: instruction, viewModel.asset, viewModel.networkName)
        walletLabel.text = viewModel.accountName
        addressLabel.text = viewModel.address
        addressLabel.accessibilityLabel = viewModel.address
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol?) {
        segmentedControl.isHidden = assetViewModel == nil
        amountView.bind(viewModel: assetViewModel)
        if assetViewModel == nil { amountView.textField.resignFirstResponder() }
        amountView.isHidden = assetViewModel == nil || segmentedControl.selectedSegmentIndex == 0
        amountView.alpha = amountView.isHidden ? 0 : 1
        if FWAppearance.receivePresentationRestyled {
            updateTypography()
        } else {
            let height = assetViewModel == nil
                ? 480 - LayoutConstants.segmentedControlHeight - UIConstants.bigOffset
                : (amountView.isHidden ? 480 : 584)
            contentView.snp.updateConstraints { make in
                make.height.equalTo(height).priority(.medium)
            }
        }
    }

    private func applyLocale() {
        navigationBar.backButton.accessibilityLabel = R.string.localizable.commonClose(
            preferredLanguages: locale.rLanguages
        )
        copyButton.imageWithTitleView?.title = R.string.localizable.commonCopy(preferredLanguages: locale.rLanguages)
        shareButton.imageWithTitleView?.title = R.string.localizable.commonShare(preferredLanguages: locale.rLanguages)

        let segmentTitles = [
            R.string.localizable.commonActionReceive(preferredLanguages: locale.rLanguages),
            R.string.localizable.commonRequest(preferredLanguages: locale.rLanguages)
        ]
        segmentedControl.setSegmentItems(segmentTitles)
        amountView.locale = locale
        if FWAppearance.receivePresentationRestyled {
            if let displayedModel { applyDisplayModel(displayedModel) }
            updateTypography()
        }
    }

    private func setupLayout() {
        backgroundColor = R.color.colorBlack19()
        layer.cornerRadius = LayoutConstants.cornerRadius
        clipsToBounds = true
        navigationBar.titleLabel.numberOfLines = 0
        navigationBar.titleLabel.lineBreakMode = .byWordWrapping
        navigationBar.titleLabel.adjustsFontForContentSizeCategory = true
        navigationBar.titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        navigationBar.leftStackView.alignment = .center
        navigationBar.backButton.snp.remakeConstraints { make in make.size.equalTo(44) }
        amountView.isHidden = true
        amountView.alpha = 0
        walletLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        addressLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(shareButton)
        addSubview(copyButton)

        contentView.stackView.addArrangedSubview(segmentedControl)
        contentView.stackView.addArrangedSubview(amountView)
        contentView.stackView.addArrangedSubview(networkLabel)
        contentView.stackView.addArrangedSubview(networkInstructionLabel)
        contentView.stackView.addArrangedSubview(qrView)
        contentView.stackView.addArrangedSubview(walletLabel)
        contentView.stackView.addArrangedSubview(addressLabel)

        navigationBar.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.height.greaterThanOrEqualTo(68)
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.bottom.equalTo(copyButton.snp.top)
            make.height.equalTo(480).priority(.medium)
        }

        amountView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalTo(UIConstants.amountViewV2Height)
        }

        qrView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.qrImageSize)
        }

        shareButton.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.height.equalTo(max(UIConstants.actionHeight, UIFont.h4Title.lineHeight + 20))
        }

        copyButton.snp.makeConstraints { make in
            make.bottom.equalTo(shareButton.snp.top).offset(-LayoutConstants.verticalOffset)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.height.equalTo(max(UIConstants.actionHeight, UIFont.h4Title.lineHeight + 20))
        }

        segmentedControl.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.segmentedControlHeight)
            make.width.equalTo(contentView.snp.width)
        }

        applyLocale()

        [networkLabel, networkInstructionLabel, walletLabel, addressLabel].forEach { view in
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }
    }
}

private extension ReceiveAndRequestAssetViewLayout {
    func setupAdaptiveLayout() {
        navigationBar.titleLabel.removeFromSuperview()
        navigationTitleLabel.textColor = R.color.colorWhite()
        navigationBar.setCenterViews([navigationTitleLabel])
        navigationBar.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.greaterThanOrEqualTo(68)
        }
        contentView.snp.remakeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            keyboardAdoptableConstraint = make.bottom.equalTo(safeAreaLayoutGuide).constraint
        }
        contentView.stackView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        [copyButton, shareButton].forEach { button in
            button.snp.removeConstraints()
            button.removeFromSuperview()
            contentView.stackView.addArrangedSubview(button)
            button.snp.makeConstraints { $0.width.equalToSuperview() }
        }
        amountView.snp.remakeConstraints { $0.width.equalToSuperview() }
        segmentedControl.snp.remakeConstraints { $0.width.equalToSuperview() }
        [walletLabel, networkInstructionLabel].forEach { $0.lineBreakMode = .byWordWrapping }
        [addressLabel, networkLabel].forEach { $0.lineBreakMode = .byCharWrapping }
        [walletLabel, addressLabel, networkLabel, networkInstructionLabel].forEach {
            $0.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        adaptiveLayoutReady = true
        updateTypography()
    }

    func updateTypography() {
        guard FWAppearance.receivePresentationRestyled, adaptiveLayoutReady else { return }
        navigationTitleLabel.font = .fw(.titleM, locale: locale, compatibleWith: traitCollection)
        networkLabel.font = .fw(.titleS, locale: locale, compatibleWith: traitCollection)
        networkInstructionLabel.font = .fw(.bodyM, locale: locale, compatibleWith: traitCollection)
        walletLabel.font = .fw(.titleS, locale: locale, compatibleWith: traitCollection)
        addressLabel.font = .fw(.monoM, locale: locale, compatibleWith: traitCollection)
        segmentedControl.configureWrapping(locale: locale, traits: traitCollection)
        amountView.configureSendPresentation(locale: locale, traits: traitCollection)
        [copyButton, shareButton].forEach { $0.configureWrappingTitle(locale: locale, compatibleWith: traitCollection) }
        setNeedsLayout()
    }
}

extension ReceiveAndRequestAssetViewLayout: FWSegmentedControlDelegate {
    func didSelect(_ segmentIndex: Int) {
        if FWAppearance.receivePresentationRestyled, segmentIndex == 0 { amountView.textField.resignFirstResponder() }
        UIView.animate(withDuration: LayoutConstants.animateDuration) {
            self.amountView.isHidden = segmentIndex == 0
            let alpha = segmentIndex == 0 ? 0.0 : 1.0
            self.amountView.alpha = alpha
            let contentViewHeight = segmentIndex == 0 ? 480 : 584
            if !FWAppearance.receivePresentationRestyled {
                self.contentView.snp.updateConstraints { make in
                    make.height.equalTo(contentViewHeight).priority(.medium)
                }
            }
            self.layoutIfNeeded()
        }
    }
}
