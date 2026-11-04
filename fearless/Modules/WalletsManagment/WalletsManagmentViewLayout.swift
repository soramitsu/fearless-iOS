import UIKit
import SoraUI
import SnapKit

enum WalletsManagmentType {
    case wallets
    case selectYourWallet(selectedWalletId: MetaAccountId?)
}

final class WalletsManagmentViewLayout: UIView {
    private enum Constants {
        static let headerHeight: CGFloat = 56.0
        static let cornerRadius: CGFloat = 20.0
        static let backButtonSize: CGFloat = 44.0
    }

    let backButton: UIButton = {
        let backButton = UIButton()
        backButton.setImage(R.image.iconBack(), for: .normal)
        backButton.accessibilityLabel = NSLocalizedString("ux.back", value: "Back", comment: "Navigation action")
        backButton.imageView?.contentMode = .center
        backButton.backgroundColor = R.color.colorSemiBlack()
        backButton.layer.cornerRadius = Constants.backButtonSize / 2
        backButton.clipsToBounds = true
        return backButton
    }()

    let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = .h4Title
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        return titleLabel
    }()

    /// Says how many stored wallets or accounts the list leaves out. Hidden while there are none.
    let recordsNoticeView: WalletRecordsNoticeControl = {
        let view = WalletRecordsNoticeControl()
        view.isHidden = true
        return view
    }()

    let tableView: SelfSizingTableView = {
        let tableView = SelfSizingTableView()
        tableView.backgroundColor = R.color.colorBlack19()
        return tableView
    }()

    let addNewWalletButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.fillColor = R.color.colorPink()!
        button.imageWithTitleView?.titleFont = .h4Title
        return button
    }()

    let importWalletButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.fillColor = R.color.colorBlack1()!
        button.imageWithTitleView?.titleFont = .h4Title
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocale()
        }
    }

    private let type: WalletsManagmentType
    private var tableTopToNavigation: Constraint?
    private var tableTopToRecordsNotice: Constraint?

    init(type: WalletsManagmentType) {
        self.type = type
        super.init(frame: .zero)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(recordsNotice: String?) {
        recordsNoticeView.titleLabel.text = recordsNotice
        recordsNoticeView.accessibilityLabel = recordsNotice
        recordsNoticeView.isHidden = recordsNotice == nil

        // Deactivate first, so the two top constraints are never active together.
        if recordsNotice == nil {
            tableTopToRecordsNotice?.deactivate()
            tableTopToNavigation?.activate()
        } else {
            tableTopToNavigation?.deactivate()
            tableTopToRecordsNotice?.activate()
        }
    }

    private func applyLocale() {
        switch type {
        case .wallets:
            titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: locale.rLanguages)
        case .selectYourWallet:
            titleLabel.text = R.string.localizable.walletManagmentSelectWalletTitle(preferredLanguages: locale.rLanguages)
        }
        importWalletButton.imageWithTitleView?.title = R.string.localizable.importWallet(
            preferredLanguages: locale.rLanguages
        )
        addNewWalletButton.imageWithTitleView?.title = R.string.localizable.walletsManagmentAddNewWallet(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        backgroundColor = R.color.colorBlack()!
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        let navView = UIView()
        addSubview(navView)
        navView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.height.greaterThanOrEqualTo(Constants.headerHeight)
        }

        navView.addSubview(backButton)
        navView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.greaterThanOrEqualTo(backButton.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.bigOffset)
        }

        backButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.backButtonSize)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        let buttonsVStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.accessoryItemsSpacing)
        addSubview(buttonsVStackView)
        buttonsVStackView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        addNewWalletButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        importWalletButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        buttonsVStackView.addArrangedSubview(addNewWalletButton)
        buttonsVStackView.addArrangedSubview(importWalletButton)

        setupListLayout(below: navView, above: buttonsVStackView)
    }

    /// The list sits right below the title unless there is something to report.
    private func setupListLayout(below navView: UIView, above buttonsVStackView: UIView) {
        addSubview(recordsNoticeView)
        recordsNoticeView.snp.makeConstraints { make in
            make.top.equalTo(navView.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            tableTopToNavigation = make.top.equalTo(navView.snp.bottom)
                .offset(UIConstants.defaultOffset).constraint
            tableTopToRecordsNotice = make.top.equalTo(recordsNoticeView.snp.bottom)
                .offset(UIConstants.defaultOffset).constraint
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            switch type {
            case .wallets:
                make.bottom.equalTo(buttonsVStackView.snp.top).offset(-UIConstants.hugeOffset)
            case .selectYourWallet:
                buttonsVStackView.isHidden = true
                make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            }
        }
        tableTopToRecordsNotice?.deactivate()
    }
}

/// A tappable warning row with a message that may wrap over several lines.
final class WalletRecordsNoticeControl: UIControl {
    private enum Constants {
        static let iconSize: CGFloat = 24.0
        static let arrowSize: CGFloat = 16.0
    }

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView(image: R.image.iconWarning())
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let arrowImageView: UIImageView = {
        let imageView = UIImageView(image: R.image.iconSmallArrow())
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        backgroundColor = R.color.colorSemiBlack()
        layer.cornerRadius = UIConstants.defaultOffset
        isAccessibilityElement = true
        accessibilityTraits = .button

        let hStackView = UIFactory.default.createHorizontalStackView(spacing: UIConstants.defaultOffset)
        hStackView.alignment = .center
        hStackView.isUserInteractionEnabled = false
        addSubview(hStackView)
        hStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }
        arrowImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.arrowSize)
        }

        hStackView.addArrangedSubview(iconImageView)
        hStackView.addArrangedSubview(titleLabel)
        hStackView.addArrangedSubview(arrowImageView)

        // Spare height in the sheet goes to the header, never to the warning row.
        titleLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().priority(.high)
        }
    }
}
