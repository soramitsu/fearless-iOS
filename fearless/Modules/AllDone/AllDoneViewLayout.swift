import UIKit

// swiftlint:disable function_body_length
final class AllDoneViewLayout: UIView {
    private enum Constants {
        static let cornerRadius: CGFloat = 20.0
        static let imageViewContainerSize: CGFloat = 80.0
        static let imageViewSize = CGSize(width: 48, height: 42)
        static let imageVerticalPosition: CGFloat = 3
        static let imageWidth: CGFloat = 15
        static let imageHeight: CGFloat = 15
        static let closeButtonInset: CGFloat = 20
        static let contentStackViewTopOffset: CGFloat = 76
        static let spacing24: CGFloat = 24
        static let spacing16: CGFloat = 16
    }

    var copyOnTap: (() -> Void)?
    private var hashString: String?

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    let closeButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = R.color.colorSemiBlack()!
        button.setImage(R.image.iconClose(), for: .normal)
        return button
    }()

    private let contentStackView: UIStackView = {
        let stack = UIFactory.default.createVerticalStackView()
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.fearlessPink()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .h2Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .p0Paragraph
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    private let infoBackground: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    private let infoStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)

    private let hashView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.valueLabel.lineBreakMode = .byTruncatingMiddle
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        return view
    }()

    let subscanButton: TriangularedButton = UIFactory.default.createDisabledButton()
    let shareButton: TriangularedButton = UIFactory.default.createMainActionButton()

    init() {
        super.init(frame: .zero)
        setupLayout()
        setupCopyHashTap()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        closeButton.rounded()
    }

    // MARK: - Public methods

    func bind(_ hashString: String) {
        self.hashString = hashString
        let hashString = NSMutableAttributedString(string: hashString + "  ")

        let imageAttachment = NSTextAttachment()
        imageAttachment.bounds = CGRect(
            x: 0,
            y: -Constants.imageVerticalPosition,
            width: Constants.imageWidth,
            height: Constants.imageHeight
        )
        if let iconAboutArrowImage = R.image.iconCopy() {
            imageAttachment.image = iconAboutArrowImage
        }

        let imageString = NSAttributedString(attachment: imageAttachment)
        hashString.append(imageString)
        hashView.valueLabel.attributedText = hashString
    }

    // MARK: - Private methods

    private func setupCopyHashTap() {
        let tapGesture = UITapGestureRecognizer()
        tapGesture.addTarget(self, action: #selector(handleHashCopyTapped))
        hashView.valueLabel.addGestureRecognizer(tapGesture)
        hashView.valueLabel.isUserInteractionEnabled = true
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .allDoneAlertAllDoneStub(preferredLanguages: locale.rLanguages)
        descriptionLabel.text = R.string.localizable
            .allDoneAlertDescriptionStub(preferredLanguages: locale.rLanguages)
        hashView.titleLabel.text = R.string.localizable
            .allDoneAlertHashStub(preferredLanguages: locale.rLanguages)
        subscanButton.imageWithTitleView?.title = R.string.localizable
            .allDoneSubscanButtonTitle(preferredLanguages: locale.rLanguages)
        shareButton.imageWithTitleView?.title = R.string.localizable
            .commonShare(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        backgroundColor = R.color.colorAlmostBlack()!
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        let indicator = UIFactory.default.createIndicatorView()
        addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.size.equalTo(UIConstants.indicatorSize)
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(Constants.closeButtonInset)
        }

        let imageViewContainer = UIView()
        imageViewContainer.backgroundColor = R.color.colorBlack()
        imageViewContainer.layer.cornerRadius = Constants.imageViewContainerSize / 2
        imageViewContainer.layer.shadowColor = R.color.colorPink()!.cgColor
        imageViewContainer.layer.shadowRadius = 12
        imageViewContainer.layer.shadowOpacity = 0.5
        imageViewContainer.snp.makeConstraints { make in
            make.size.equalTo(Constants.imageViewContainerSize)
        }

        imageViewContainer.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(Constants.imageViewSize)
        }

        addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.contentStackViewTopOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.bigOffset)
        }

        contentStackView.addArrangedSubview(imageViewContainer)
        contentStackView.setCustomSpacing(Constants.spacing24, after: imageViewContainer)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.setCustomSpacing(Constants.spacing16, after: titleLabel)
        contentStackView.addArrangedSubview(descriptionLabel)
        contentStackView.setCustomSpacing(Constants.spacing24, after: descriptionLabel)

        contentStackView.addArrangedSubview(infoBackground)
        infoBackground.addSubview(infoStackView)
        infoStackView.addArrangedSubview(hashView)

        let buttonHStachView = UIFactory.default.createHorizontalStackView(spacing: UIConstants.offset12)
        buttonHStachView.distribution = .fillEqually
        buttonHStachView.addArrangedSubview(subscanButton)
        buttonHStachView.addArrangedSubview(shareButton)
        contentStackView.setCustomSpacing(Constants.spacing24, after: infoBackground)
        contentStackView.addArrangedSubview(buttonHStachView)

        buttonHStachView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        infoBackground.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        infoStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        hashView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }
    }

    // MARK: - Private actions

    @objc private func handleHashCopyTapped() {
        UIPasteboard.general.string = hashString
        copyOnTap?()
    }
}
