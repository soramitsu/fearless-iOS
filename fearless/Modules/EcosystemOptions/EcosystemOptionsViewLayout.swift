import UIKit

final class EcosystemOptionsViewLayout: UIView {
    private enum Constants {
        static let headerHeight: CGFloat = 56.0
        static let cornerRadius: CGFloat = 20.0
    }

    let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = .h3Title
        return titleLabel
    }()

    let backupWalletButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.fillColor = R.color.colorBlack1()!
        button.triangularedView?.shadowOpacity = 0
        button.imageWithTitleView?.titleFont = .h4Title
        return button
    }()

    let accountsDetailsButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.fillColor = R.color.colorBlack1()!
        button.triangularedView?.shadowOpacity = 0
        button.imageWithTitleView?.titleFont = .h4Title
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocale()
        }
    }

    private lazy var buttons: [TriangularedButton] = {
        [
            backupWalletButton,
            accountsDetailsButton
        ]
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private methods

    private func applyLocale() {
        titleLabel.text = "Account options"
        backupWalletButton.imageWithTitleView?.title = "Backup chain accounts"
        accountsDetailsButton.imageWithTitleView?.title = "Chain accounts"
    }

    private func setupLayout() {
        backgroundColor = R.color.colorAlmostBlack()!
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        let navView = UIView()
        addSubview(navView)
        navView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.headerHeight)
        }

        navView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        let indicator = UIFactory.default.createIndicatorView()

        navView.addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.size.equalTo(UIConstants.indicatorSize)
            make.top.equalTo(navView.snp.top)
            make.centerX.equalTo(navView.snp.centerX)
        }

        buttons.forEach {
            $0.snp.makeConstraints { make in
                make.height.equalTo(UIConstants.actionHeight)
            }
        }

        let vStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.accessoryItemsSpacing)
        vStackView.backgroundColor = .clear
        addSubview(vStackView)
        vStackView.snp.makeConstraints { make in
            make.top.equalTo(navView.snp.bottom).offset(UIConstants.accessoryItemsSpacing)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.accessoryItemsSpacing)
        }

        buttons.forEach {
            vStackView.addArrangedSubview($0)
        }
    }
}
