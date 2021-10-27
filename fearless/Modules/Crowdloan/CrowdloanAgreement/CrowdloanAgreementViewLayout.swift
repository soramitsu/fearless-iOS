import UIKit

final class CrowdloanAgreementViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.alignment = .leading
        view.stackView.spacing = UIConstants.verticalInset
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textAlignment = .left
        label.numberOfLines = 2
        return label
    }()

    let textView: UITextView = {
        let textView = UITextView()
        textView.font = .p2Paragraph
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }()

    let confirmAgreementButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let termsSwitchView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorAccent()
        return switchView
    }()

    let termsLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.font = .p1Paragraph
        label.numberOfLines = 2
        return label
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

        setupLayout()
        applyLocalization()

        backgroundColor = R.color.colorBlack()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        termsLabel.text = R.string.localizable.crowdloanPrivacyPolicy(preferredLanguages: locale.rLanguages)

        confirmAgreementButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: locale.rLanguages
        ).capitalized
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.width.equalToSuperview().offset(-2 * UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        contentView.stackView.addArrangedSubview(titleLabel)
        contentView.stackView.addArrangedSubview(textView)

        let privacyView = UIView()
        contentView.stackView.addArrangedSubview(privacyView)
        privacyView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        privacyView.addSubview(termsSwitchView)
        termsSwitchView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        privacyView.addSubview(termsLabel)
        termsLabel.snp.makeConstraints { make in
            make.leading.equalTo(termsSwitchView.snp.trailing).offset(16.0)
            make.trailing.centerY.equalToSuperview()
        }

        contentView.stackView.setCustomSpacing(16.0, after: privacyView)

        addSubview(confirmAgreementButton)
        confirmAgreementButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.scrollBottomOffset = 2 * UIConstants.horizontalInset + UIConstants.actionHeight
    }
}
