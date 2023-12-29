import UIKit

final class NftFiltersViewLayout: UIView {
    lazy var navigationBar: BaseNavigationBar = {
        let navBar = BaseNavigationBar()
        navBar.backButton.isHidden = true
        return navBar
    }()

    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconCloseWhiteTransparent(), for: .normal)
        return button
    }()

    let tableView: SelfSizingTableView = {
        let tableView = SelfSizingTableView()
        tableView.backgroundColor = .clear
        return tableView
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {
        navigationBar.titleLabel.text = R.string.localizable.nftsFiltersTitle(preferredLanguages: locale.rLanguages)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack19()

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(navigationBar)
        addSubview(tableView)

        navigationBar.setRightViews([closeButton])

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
