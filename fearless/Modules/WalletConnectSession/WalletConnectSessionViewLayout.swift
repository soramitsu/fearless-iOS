import UIKit

final class WalletConnectSessionViewLayout: UIView {
    private enum Constants {
        static let cornerRadius: CGFloat = 20.0
        static let imageViewContainerSize: CGFloat = 80.0
        static let imageViewSize = CGSize(width: 48, height: 42)
        static let closeButton: CGFloat = 32.0
    }

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    private let navigationTitle: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        return label
    }()

    let closeButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = R.color.colorSemiBlack()
        button.setImage(R.image.iconClose(), for: .normal)
        return button
    }()

    private let contentStackView: UIStackView = {
        let stack = UIFactory.default.createVerticalStackView()
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()

    private let imageViewContainer = UIView()
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.fearlessPink()
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .h3Title
        return label
    }()

    let tableView: SelfSizingTableView = {
        let tableView = SelfSizingTableView()
        tableView.backgroundColor = R.color.colorBlack19()
        tableView.isScrollEnabled = false
        return tableView
    }()

    private let messageView: DetailsTriangularedView = {
        let view = UIFactory.default.createDetailsView(with: .withoutIcon, filled: false)
        view.triangularedBackgroundView?.fillColor = R.color.colorSemiBlack()!
        view.triangularedBackgroundView?.highlightedFillColor = R.color.colorSemiBlack()!
        view.triangularedBackgroundView?.strokeColor = R.color.colorWhite8()!
        view.triangularedBackgroundView?.highlightedStrokeColor = R.color.colorWhite8()!
        view.triangularedBackgroundView?.strokeWidth = 0.5
        view.titleLabel.font = .h5Title
        view.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
        view.subtitleLabel?.numberOfLines = 1
        return view
    }()

    private lazy var warningLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private lazy var warningView: UIView = {
        let view = createWarningView(with: warningLabel)
        return view
    }()

    let actionButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        button.applyEnabledStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        closeButton.rounded()
        imageViewContainer.rounded()
    }

    func bind(viewModel: WalletConnectSessionViewModel) {
        titleLabel.text = viewModel.dApp
        messageView.subtitle = viewModel.payload.stringRepresentation
        warningLabel.attributedText = viewModel.warning
    }

    // MARK: - Private methods

    private func setupLayout() {
        backgroundColor = R.color.colorBlack19()!
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        let indicator = UIFactory.default.createIndicatorView()
        addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.size.equalTo(UIConstants.indicatorSize)
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }

        addSubview(navigationTitle)
        navigationTitle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(20)
            make.size.equalTo(Constants.closeButton)
        }

        imageViewContainer.backgroundColor = R.color.colorBlack()
        imageViewContainer.layer.shadowColor = R.color.colorPink()!.cgColor
        imageViewContainer.layer.shadowRadius = 12
        imageViewContainer.layer.shadowOpacity = 0.5
        imageViewContainer.snp.makeConstraints { make in
            make.size.equalTo(80)
        }

        imageViewContainer.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(76)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.bigOffset)
        }

        contentStackView.addArrangedSubview(imageViewContainer)
        contentStackView.setCustomSpacing(16, after: imageViewContainer)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.setCustomSpacing(16, after: titleLabel)
        contentStackView.addArrangedSubview(tableView)
        contentStackView.setCustomSpacing(16, after: tableView)
        contentStackView.addArrangedSubview(messageView)
        contentStackView.setCustomSpacing(24, after: messageView)
        contentStackView.addArrangedSubview(warningView)
        contentStackView.setCustomSpacing(16, after: warningView)

        messageView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(80)
        }

        contentStackView.addArrangedSubview(actionButton)
        [
            actionButton,
            titleLabel,
            messageView,
            warningView
        ].forEach { view in
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            }
        }
    }

    private func createWarningView(with label: UILabel) -> UIView {
        let iconView = UIImageView(image: R.image.iconWarning())
        iconView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }

        let stack = UIFactory.default.createHorizontalStackView(spacing: 8)
        stack.alignment = .top
        stack.distribution = .fillProportionally

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)

        return stack
    }

    private func applyLocalization() {
        messageView.title = "Message"
        navigationTitle.text = "Sign this message?"
        actionButton.imageWithTitleView?.title = "Preview"
    }
}
