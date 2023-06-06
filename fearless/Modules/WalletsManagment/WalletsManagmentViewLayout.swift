import UIKit
import SoraUI

enum WalletsManagmentType {
    case wallets
    case selectYourWallet(selectedWalletId: MetaAccountId?)
}

final class WalletsManagmentViewLayout: UIView {
    private enum Constants {
        static let headerHeight: CGFloat = 56.0
        static let cornerRadius: CGFloat = 20.0
        static let backButtonSize: CGFloat = 32.0
    }

    let backButton: UIButton = {
        let backButton = UIButton()
        backButton.setImage(R.image.iconBack(), for: .normal)
        backButton.imageView?.contentMode = .center
        backButton.backgroundColor = R.color.colorSemiBlack()
        backButton.layer.cornerRadius = 16
        backButton.clipsToBounds = true
        return backButton
    }()

    let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = .h4Title
        return titleLabel
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

    init(type: WalletsManagmentType) {
        self.type = type
        super.init(frame: .zero)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocale() {
        switch type {
        case .wallets:
            titleLabel.text = R.string.localizable.tabbarWalletTitle(preferredLanguages: locale.rLanguages)
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
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.headerHeight)
        }

        navView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        navView.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.backButtonSize)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        let buttonsVStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.accessoryItemsSpacing)
        addSubview(buttonsVStackView)
        buttonsVStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
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

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(navView.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
            switch type {
            case .wallets:
                make.bottom.equalTo(buttonsVStackView.snp.top).offset(-UIConstants.hugeOffset)
            case .selectYourWallet:
                buttonsVStackView.isHidden = true
                make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            }
        }
    }
}
