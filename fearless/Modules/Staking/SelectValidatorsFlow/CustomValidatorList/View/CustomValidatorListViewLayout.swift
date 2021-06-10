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

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        return stackView
    }()

    private let stackContainerView = UIView()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = R.color.colorBlack()
        tableView.separatorColor = R.color.colorDarkGray()
        return tableView
    }()

    let searchButton: UIBarButtonItem = {
        UIBarButtonItem(image: R.image.iconSearch(), style: .plain, target: nil, action: nil)
    }()

    let filterButton: UIBarButtonItem = {
        UIBarButtonItem(image: R.image.iconFilter(), style: .plain, target: nil, action: nil)
    }()

    let fillRestButton: GradientButton = {
        createGradientButton()
    }()

    let clearButton: GradientButton = {
        createGradientButton()
    }()

    let deselectButton: GradientButton = {
        createGradientButton()
    }()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    static func createGradientButton() -> GradientButton {
        let button = GradientButton()
        button.applyDefaultStyle()
        button.gradientBackgroundView?.cornerRadius = Constants.auxButtonHeight / 2.0
        button.contentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 6.0, right: 12.0)
        return button
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        stackView.addArrangedSubview(fillRestButton)
        stackView.addArrangedSubview(clearButton)
        stackView.addArrangedSubview(deselectButton)

        stackContainerView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(stackContainerView.snp.leading).inset(UIConstants.horizontalInset)
            make.trailing.equalTo(stackContainerView.snp.trailing).inset(UIConstants.horizontalInset)
        }

        scrollView.addSubview(stackContainerView)
        stackContainerView.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalToSuperview()
        }

        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.trailing.leading.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(Constants.auxButtonContainerHeight)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }

        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }
}
