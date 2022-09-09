import UIKit

final class SelectCurrencyViewLayout: UIView {
    private enum Constants {
        static let contentInset = UIEdgeInsets(
            top: UIConstants.bigOffset,
            left: 0,
            bottom: UIConstants.bigOffset,
            right: 0
        )
        static let headerHeight: CGFloat = 56.0
        static let cornerRadius: CGFloat = 20.0
        static let backButtonSize: CGFloat = 32.0
    }

    private let isModal: Bool
    var locale: Locale = .current {
        didSet {
            applyLocale()
        }
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

    let rightButton = UIButton()

    let tableView: SelfSizingTableView = {
        let tableView = SelfSizingTableView()
        tableView.separatorStyle = .none
        tableView.backgroundColor = R.color.colorBlack()
        tableView.contentInset = Constants.contentInset
        return tableView
    }()

    init(isModal: Bool) {
        self.isModal = isModal
        super.init(frame: .zero)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocale() {
        titleLabel.text = R.string.localizable.commonCurrency(preferredLanguages: locale.rLanguages)
        rightButton.setTitle(
            R.string.localizable.commonDone(preferredLanguages: locale.rLanguages),
            for: .normal
        )
    }

    private func setupLayout() {
        backgroundColor = R.color.colorBlack()!
        if isModal {
            layer.cornerRadius = Constants.cornerRadius
            clipsToBounds = true
            snp.makeConstraints { make in
                make.height.equalTo(UIScreen.main.bounds.height / 2.5)
            }
            tableView.backgroundColor = R.color.colorBlack()
        }

        let navView = UIView()
        addSubview(navView)
        navView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
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

        if !isModal {
            navView.addSubview(rightButton)
            rightButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
                make.centerY.equalToSuperview()
            }
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(navView.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
