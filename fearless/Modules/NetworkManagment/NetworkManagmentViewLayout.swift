import UIKit
import SnapKit

final class NetworkManagmentViewLayout: UIView {
    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    var keyboardAdoptableConstraint: Constraint?

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.set(.push)
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let searchTextField: SearchTextField = {
        let searchTextField = SearchTextField()
        searchTextField.triangularedView?.cornerCut = [.bottomRight, .topLeft]
        searchTextField.triangularedView?.strokeWidth = UIConstants.separatorHeight
        searchTextField.triangularedView?.strokeColor = R.color.colorStrokeGray() ?? .lightGray
        searchTextField.triangularedView?.fillColor = R.color.colorBlack50()!
        searchTextField.triangularedView?.highlightedFillColor = R.color.colorBlack50()!
        searchTextField.triangularedView?.shadowOpacity = 0
        searchTextField.textField.backgroundColor = R.color.colorBlack50()
        searchTextField.textField.tintColor = R.color.colorWhite50()
        return searchTextField
    }()

    let filtersStackView: UIStackView = {
        let view = UIStackView()
        view.backgroundColor = R.color.colorBlack19()
        view.axis = .horizontal
        view.distribution = .fillProportionally
        view.spacing = 10
        view.isUserInteractionEnabled = true
        return view
    }()

    lazy var allFilterButton: TriangularedButton = {
        createFilterButton()
    }()

    lazy var popularFilterButton: TriangularedButton = {
        createFilterButton()
    }()

    lazy var favouriteFilterButton: TriangularedButton = {
        createFilterButton()
    }()

    let container = UIView()
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = R.color.colorBlack19()
        return tableView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(filter: NetworkManagmentSelect) {
        allFilterButton.isSelected = filter.isAllFilter || filter.isChainSelected
        popularFilterButton.isSelected = filter.isPopularFilter
        favouriteFilterButton.isSelected = filter.isFavouriteFilter
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(searchTextField)
        addSubview(filtersStackView)
        addSubview(container)
        container.addSubview(tableView)

        [allFilterButton, popularFilterButton, favouriteFilterButton].forEach {
            $0.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            filtersStackView.addArrangedSubview($0)
        }

        navigationBar.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(56)
        }

        searchTextField.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        filtersStackView.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(UIConstants.offset12)
            make.leading.equalToSuperview().inset(UIConstants.bigOffset)
            make.trailing.greaterThanOrEqualToSuperview().offset(UIConstants.bigOffset).priority(.low)
        }

        container.snp.makeConstraints { make in
            make.top.equalTo(filtersStackView.snp.bottom).offset(UIConstants.offset12)
            make.leading.trailing.equalToSuperview()
            keyboardAdoptableConstraint = make.bottom.equalTo(safeAreaLayoutGuide).constraint
        }

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func createFilterButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.triangularedView?.shadowOpacity = 0
        button.triangularedView?.fillColor = R.color.colorBlack50()!
        button.triangularedView?.highlightedFillColor = R.color.colorBlack50()!
        button.triangularedView?.strokeColor = R.color.colorStrokeGray()!
        button.triangularedView?.highlightedStrokeColor = R.color.colorPink()!
        button.triangularedView?.strokeWidth = UIConstants.separatorHeight

        button.imageWithTitleView?.titleColor = R.color.colorStrokeGray()
        button.imageWithTitleView?.titleFont = .h6Title

        return button
    }

    private func applyLocalization() {
        navigationBar.setTitle(R.string.localizable.commonNetworkManagement(preferredLanguages: locale.rLanguages))
        searchTextField.textField.placeholder = R.string.localizable.commonSearch(preferredLanguages: locale.rLanguages)
        allFilterButton.imageWithTitleView?.title = R.string.localizable.stakingAnalyticsPeriodAll(preferredLanguages: locale.rLanguages).uppercased()
        popularFilterButton.imageWithTitleView?.title = R.string.localizable.networkManagementPopular(preferredLanguages: locale.rLanguages).uppercased()
        favouriteFilterButton.imageWithTitleView?.title = R.string.localizable.networkManagmentFavourite(preferredLanguages: locale.rLanguages).uppercased()
    }
}
