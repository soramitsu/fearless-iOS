import UIKit

final class CrowdloanAgreementSignedViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.alignment = .leading
        view.stackView.spacing = UIConstants.hugeOffset
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

    let textLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textAlignment = .left
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        return label
    }()

    let hashLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textAlignment = .left
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        return label
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.applyEnabledStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyLocalization()

        backgroundColor = R.color.colorBlack()
    }

    func bind(to viewModel: CrowdloanAgreementSignedViewModel) {
        if let hash = viewModel.hash {
            let attributedHashString = NSAttributedString(
                string: hash,
                attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue,
                             .foregroundColor: R.color.colorAccent()]
            )
            hashLabel.attributedText = attributedHashString
        }
    }

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.transactionSuccessful(preferredLanguages: locale.rLanguages)
        textLabel.text = R.string.localizable.moonbeamSignedSuccessful(preferredLanguages: locale.rLanguages)
        continueButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: locale.rLanguages
        ).capitalized
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.width.equalToSuperview().offset(-1 * UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        contentView.stackView.addArrangedSubview(titleLabel)

        contentView.stackView.addArrangedSubview(textLabel)

        contentView.stackView.addArrangedSubview(hashLabel)

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.scrollBottomOffset = 2 * UIConstants.horizontalInset + UIConstants.actionHeight
    }
}
