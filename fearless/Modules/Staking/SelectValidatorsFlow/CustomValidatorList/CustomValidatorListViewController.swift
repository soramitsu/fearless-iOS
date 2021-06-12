import UIKit
import SoraFoundation

final class CustomValidatorListViewController: UIViewController, ViewHolder {
    typealias RootViewType = CustomValidatorListViewLayout

    let presenter: CustomValidatorListPresenterProtocol

    private var cellViewModels: [CustomValidatorCellViewModel] = []
    private var selectedValidatorsCount: Int = 0

    let searchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconSearchWhite(), for: .normal)
        return button
    }()

    let filterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconFilterActive(), for: .normal)
        return button
    }()

    // MARK: - Lifecycle

    init(
        presenter: CustomValidatorListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol? = nil
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CustomValidatorListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupTable()
        setupNavigationBar()
        setupActionButtons()
        presenter.setup()
    }

    // MARK: - Private functions

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CustomValidatorCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CustomValidatorListHeaderView.self)
    }

    private func setupNavigationBar() {
        let filterBarbutton = UIBarButtonItem(customView: filterButton)
        let searchBarbutton = UIBarButtonItem(customView: searchButton)

        navigationItem.rightBarButtonItems = [filterBarbutton,
                                              searchBarbutton]

        filterButton.addTarget(self, action: #selector(tapFilterButton), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(tapSearchButton), for: .touchUpInside)
    }

    private func applyHeaderViewModel() {
        rootView.deselectButton.isEnabled = selectedValidatorsCount > 0
        rootView.proceedButton.isEnabled = selectedValidatorsCount > 0
    }

    private func setupActionButtons() {
        rootView.fillRestButton.addTarget(self, action: #selector(tapFillRestButton), for: .touchUpInside)
        rootView.clearButton.addTarget(self, action: #selector(tapClearButton), for: .touchUpInside)
        rootView.deselectButton.addTarget(self, action: #selector(tapDeselectButton), for: .touchUpInside)
        rootView.proceedButton.addTarget(self, action: #selector(tapProceedButton), for: .touchUpInside)

        applyHeaderViewModel()
    }

    // MARK: - Actions

    @objc
    private func handleValidatorInfo() {
        // TODO: handle right validator info
        presenter.didSelectValidator(at: 0)
    }

    @objc private func tapFilterButton() {
        presenter.presentFilter()
    }

    @objc private func tapSearchButton() {
        presenter.presentSearch()
    }

    @objc private func tapFillRestButton() {
        #warning("Not implemented")
    }

    @objc private func tapClearButton() {
        presenter.clearFilter()
    }

    @objc private func tapDeselectButton() {
        #warning("Not implemented")
    }

    @objc private func tapProceedButton() {
        #warning("Not implemented")
    }
}

// MARK: - Localizable

extension CustomValidatorListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .stakingCustomValidatorsListTitle(preferredLanguages: selectedLocale.rLanguages)

            rootView.fillRestButton.imageWithTitleView?.title = R.string.localizable
                .stakingCustomFillButtonTitle(preferredLanguages: selectedLocale.rLanguages).uppercased()
            rootView.clearButton.imageWithTitleView?.title = R.string.localizable
                .stakingCustomClearButtonTitle(preferredLanguages: selectedLocale.rLanguages).uppercased()
            rootView.deselectButton.imageWithTitleView?.title = R.string.localizable
                .stakingCustomDeselectButtonTitle(preferredLanguages: selectedLocale.rLanguages).uppercased()

            rootView.proceedButton.imageWithTitleView?.title = "Select validators (max 16)"
        }
    }
}

// MARK: - CustomValidatorListViewProtocol

extension CustomValidatorListViewController: CustomValidatorListViewProtocol {
    func reload(with viewModel: [CustomValidatorCellViewModel]) {
        cellViewModels = viewModel
        rootView.tableView.reloadData()
    }

    func setFilterAppliedState(to applied: Bool) {
        let image = applied ? R.image.iconFilterActive() : R.image.iconFilter()
        filterButton.setImage(image, for: .normal)
        rootView.clearButton.isEnabled = applied
    }
}

// MARK: - UITableViewDataSource

extension CustomValidatorListViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        cellViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(CustomValidatorCell.self)!
        let viewModel = cellViewModels[indexPath.row]
        cell.bind(viewModel: viewModel)
        cell.infoButton.addTarget(self, action: #selector(handleValidatorInfo), for: .touchUpInside)
        return cell
    }
}

extension CustomValidatorListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let headerView: CustomValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(title: "Validators: 200 of 940", details: "Rewards (APY)")
        return headerView
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        26.0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        cellViewModels[indexPath.row].isSelected = !cellViewModels[indexPath.row].isSelected
        tableView.reloadRows(at: [indexPath], with: .automatic)

        presenter.changeValidatorSelection(at: indexPath.row)
    }
}
