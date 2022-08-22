import UIKit
import SoraUI

protocol WalletOptionViewLayoutDelegate: AnyObject {
    func walletDetailsDidTap()
    func exportWalletDidTap()
    func deleteWalletDidTap()
}

final class WalletOptionViewLayout: UIView {
    private enum Constants {
        static let headerHeight: CGFloat = 56.0
        static let cornerRadius: CGFloat = 20.0
    }

    let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = .h3Title
        return titleLabel
    }()

    let walletDetailsButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.fillColor = R.color.colorBlack1()!
        button.triangularedView?.shadowOpacity = 0
        button.imageWithTitleView?.titleFont = .h4Title
        return button
    }()

    let exportWalletButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.fillColor = R.color.colorBlack1()!
        button.triangularedView?.shadowOpacity = 0
        button.imageWithTitleView?.titleFont = .h4Title
        return button
    }()

    let deleteWalletButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.fillColor = R.color.colorBlack1()!
        button.triangularedView?.shadowOpacity = 0
        button.imageWithTitleView?.titleFont = .h4Title
        button.imageWithTitleView?.titleColor = R.color.colorAccent()!
        return button
    }()

    weak var delegate: WalletOptionViewLayoutDelegate?

    var locale: Locale = .current {
        didSet {
            applyLocale()
        }
    }

    private lazy var buttons: [TriangularedButton] = {
        [
            walletDetailsButton,
            exportWalletButton,
            deleteWalletButton
        ]
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Actions

    @objc private func handleWalletDetailsDidTap() {
        delegate?.walletDetailsDidTap()
    }

    @objc private func handleWalletExportDidTap() {
        delegate?.exportWalletDidTap()
    }

    @objc private func handleDeleteWalletDidTap() {
        delegate?.deleteWalletDidTap()
    }

    // MARK: - Private methods

    private func setupActions() {
        walletDetailsButton.addTarget(self, action: #selector(handleWalletDetailsDidTap), for: .touchUpInside)
        exportWalletButton.addTarget(self, action: #selector(handleWalletExportDidTap), for: .touchUpInside)
        deleteWalletButton.addTarget(self, action: #selector(handleDeleteWalletDidTap), for: .touchUpInside)
    }

    private func applyLocale() {
        titleLabel.text = R.string.localizable.walletOptionsTitle(preferredLanguages: locale.rLanguages)

        walletDetailsButton.imageWithTitleView?.title = R.string.localizable.walletOptionsDetails(
            preferredLanguages: locale.rLanguages
        )
        exportWalletButton.imageWithTitleView?.title = R.string.localizable.walletOptionsExport(
            preferredLanguages: locale.rLanguages
        )
        deleteWalletButton.imageWithTitleView?.title = R.string.localizable.walletOptionsDelete(
            preferredLanguages: locale.rLanguages
        )
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
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
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

        vStackView.addArrangedSubview(walletDetailsButton)
        vStackView.addArrangedSubview(exportWalletButton)
        vStackView.addArrangedSubview(deleteWalletButton)
    }
}
