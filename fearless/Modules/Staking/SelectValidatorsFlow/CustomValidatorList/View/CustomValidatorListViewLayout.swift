import SoraUI

final class CustomValidatorListViewLayout: UIView {
    private enum Constants {
        static let auxButtonHeight: CGFloat = 24.0
        static let auxButtonContainerHeight: CGFloat = 56.0
    }

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private(set) var searchTextField: SearchTextField = UIFactory.default.createSearchTextField()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        return stackView
    }()

    private let stackContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlack()
        return view
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = R.color.colorBlack19()
        tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 100.0, right: 0.0)
        return tableView
    }()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        button.contentOpacityWhenDisabled = 1.0
        return button
    }()

    private static func createRoundedButton() -> RoundedButton {
        let button = RoundedButton()
        button.applyEnabledStyle()
        button.opacityAnimationDuration = 0
        button.roundedBackgroundView?.cornerRadius = Constants.auxButtonHeight / 2.0
        button.contentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 6.0, right: 12.0)
        button.imageWithTitleView?.titleFont = UIFont.capsTitle
        return button
    }

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        backgroundColor = R.color.colorBlack19()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(searchTextField)
        searchTextField.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
        }
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.bottom.trailing.equalToSuperview()
        }

        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }

    private func applyLocalization() {
        searchTextField.textField.placeholder = R.string.localizable.stakingValidatorSearchPlaceholder(
            preferredLanguages: locale.rLanguages
        )
    }
}
