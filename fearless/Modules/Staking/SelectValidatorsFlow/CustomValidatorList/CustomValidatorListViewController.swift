import UIKit
import SoraFoundation

final class CustomValidatorListViewController: UIViewController, ViewHolder {
    typealias RootViewType = CustomValidatorListViewLayout

    let presenter: CustomValidatorListPresenterProtocol
    let selectedValidatorsLimit: Int

    private var cellViewModels: [CustomValidatorCellViewModel] = []
    private var headerViewModel: TitleWithSubtitleViewModel?
    private var selectedValidatorsCount: Int = 0
    private var electedValidatorsCount: Int = 0

    private var filterIsApplied: Bool = true

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
        selectedValidatorsLimit: Int,
        localizationManager: LocalizationManagerProtocol? = nil
    ) {
        self.presenter = presenter
        self.selectedValidatorsLimit = selectedValidatorsLimit

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

    private func setupActionButtons() {
        rootView.fillRestButton.addTarget(self, action: #selector(tapFillRestButton), for: .touchUpInside)
        rootView.clearButton.addTarget(self, action: #selector(tapClearButton), for: .touchUpInside)
        rootView.deselectButton.addTarget(self, action: #selector(tapDeselectButton), for: .touchUpInside)
        rootView.proceedButton.addTarget(self, action: #selector(tapProceedButton), for: .touchUpInside)

        updateFillRestButton()
        updateDeselectButton()
        updateProceedButton()
    }

    private func updateFillRestButton() {
        rootView.fillRestButton.isEnabled =
            selectedValidatorsCount < selectedValidatorsLimit
    }

    private func updateClearFiltersButton() {
        let image = filterIsApplied ? R.image.iconFilterActive() : R.image.iconFilter()
        filterButton.setImage(image, for: .normal)
        rootView.clearButton.isEnabled = filterIsApplied
    }

    private func updateDeselectButton() {
        rootView.deselectButton.isEnabled = selectedValidatorsCount > 0
    }

    private func updateProceedButton() {
        let buttonTitle: String
        let enabled: Bool

        if selectedValidatorsCount == 0 {
            enabled = false
            buttonTitle = R.string.localizable
                .stakingCustomProceedButtonDisabledTitle(
                    selectedValidatorsLimit,
                    preferredLanguages: selectedLocale.rLanguages
                )
        } else {
            enabled = true
            buttonTitle = R.string.localizable
                .stakingCustomProceedButtonEnabledTitle(
                    selectedValidatorsCount,
                    selectedValidatorsLimit,
                    preferredLanguages: selectedLocale.rLanguages
                )
        }

        rootView.proceedButton.imageWithTitleView?.title = buttonTitle
        rootView.proceedButton.isEnabled = enabled
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
        presenter.fillWithRecommended()
    }

    @objc private func tapClearButton() {
        presenter.clearFilter()
    }

    @objc private func tapDeselectButton() {
        presenter.deselectAll()
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

            updateProceedButton()
        }
    }
}

// MARK: - CustomValidatorListViewProtocol

extension CustomValidatorListViewController: CustomValidatorListViewProtocol {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]? = nil) {
        cellViewModels = viewModel.cellViewModels
        headerViewModel = viewModel.headerViewModel

        if let indexes = indexes {
            let indexPaths = indexes.map {
                IndexPath(row: $0, section: 0)
            }
            rootView.tableView.reloadRows(at: indexPaths, with: .none)
        } else {
            rootView.tableView.reloadData()
        }

        selectedValidatorsCount = cellViewModels.filter {
            $0.isSelected
        }.count

        updateFillRestButton()
        updateDeselectButton()
        updateProceedButton()
    }

    func setFilterAppliedState(to applied: Bool) {
        filterIsApplied = applied
        updateClearFiltersButton()
    }

    func updateHeaderViewModel(to viewModel: TitleWithSubtitleViewModel) {
        headerViewModel = viewModel
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.changeValidatorSelection(at: indexPath.row)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard headerViewModel != nil else { return 0 }
        return 26.0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let headerViewModel = headerViewModel else { return nil }
        let headerView: CustomValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(viewModel: headerViewModel)
        return headerView
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        100.0
    }

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        UIView()
    }
}
