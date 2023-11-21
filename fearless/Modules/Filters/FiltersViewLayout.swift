import UIKit

final class FiltersViewLayout: UIView {
    lazy var navigationBar: BaseNavigationBar = {
        let navBar = BaseNavigationBar()
        navBar.set(.present)
        return navBar
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let tableView: SelfSizingTableView = {
        let tableView = SelfSizingTableView()
        tableView.backgroundColor = .clear
        return tableView
    }()

    let applyButton: TriangularedButton = UIFactory.default.createMainActionButton()

    let resetButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = .p0Paragraph
        button.setTitleColor(R.color.colorWhite(), for: .normal)
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {
        resetButton.setTitle(R.string.localizable.commonReset(preferredLanguages: locale.rLanguages), for: .normal)
        navigationTitleLabel.text = R.string.localizable.walletFiltersTitle(preferredLanguages: locale.rLanguages)
        applyButton.imageWithTitleView?.title = R.string.localizable.commonApply(preferredLanguages: locale.rLanguages)
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

        navigationBar.setCenterViews([navigationTitleLabel])
        navigationBar.setRightViews([resetButton])

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.width.equalToSuperview()
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }

    func bind(viewModel: FiltersViewModel) {
        switch viewModel.mode {
        case .multiSelection:
            addApplyButtonIfNeeded()
        case .singleSelection:
            resetButton.isHidden = true
        }
    }

    private func addApplyButtonIfNeeded() {
        guard applyButton.superview == nil else {
            return
        }

        addSubview(applyButton)

        applyButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(UIConstants.hugeOffset)
            make.width.equalToSuperview().inset(UIConstants.defaultOffset * 2)
            make.centerX.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }

        tableView.snp.remakeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.width.equalToSuperview()
            make.centerX.equalToSuperview()
            make.bottom.equalTo(applyButton.snp.top).inset(UIConstants.bigOffset)
        }
    }
}
