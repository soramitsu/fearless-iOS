import UIKit
import SoraFoundation

final class CustomValidatorListViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = CustomValidatorListViewLayout

    let presenter: CustomValidatorListPresenterProtocol

    private var cellViewModels: [CustomValidatorCellViewModel] = []
    private var headerViewModel: TitleWithSubtitleViewModel?
    private var selectedValidatorsCount: Int = 0
    private var selectedValidatorsLimit: Int = 0

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

        rootView.searchTextField.onTextDidChanged = { [weak self] text in
            self?.presenter.searchTextDidChange(text)
        }
    }

    // MARK: - Private functions

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CustomValidatorCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CustomValidatorListHeaderView.self)
        rootView.tableView.rowHeight = 77.0
        rootView.tableView.separatorStyle = .none
    }

    private func setupNavigationBar() {
        let filterBarbutton = UIBarButtonItem(customView: filterButton)

        navigationItem.rightBarButtonItems = [filterBarbutton]

        filterButton.addTarget(self, action: #selector(tapFilterButton), for: .touchUpInside)
    }

    private func setupActionButtons() {
        rootView.proceedButton.addTarget(self, action: #selector(tapProceedButton), for: .touchUpInside)

        updateProceedButton(title: nil)
    }

    private func updateSetFiltersButton() {
        let image = filterIsApplied ? R.image.iconFilterActive() : R.image.iconFilter()
        filterButton.setImage(image, for: .normal)
    }

    private func updateProceedButton(title: String?) {
        let buttonTitle: String
        let isEnabled: Bool

        if selectedValidatorsCount == 0 {
            isEnabled = false

            buttonTitle = title ?? R.string.localizable
                .stakingCustomProceedButtonDisabledTitle(
                    selectedValidatorsLimit,
                    preferredLanguages: selectedLocale.rLanguages
                )

        } else {
            isEnabled = true

            buttonTitle = title ?? R.string.localizable
                .stakingCustomProceedButtonEnabledTitle(
                    selectedValidatorsCount,
                    selectedValidatorsLimit,
                    preferredLanguages: selectedLocale.rLanguages
                )
        }

        rootView.proceedButton.imageWithTitleView?.title = buttonTitle

        if isEnabled {
            rootView.proceedButton.applyEnabledStyle()
        } else {
            rootView.proceedButton.applyDisabledStyle()
        }
    }

    // MARK: - Actions

    @objc private func tapFilterButton() {
        presenter.presentFilter()
    }

    @objc private func tapProceedButton() {
        presenter.proceed()
    }
}

// MARK: - Localizable

extension CustomValidatorListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .stakingCustomValidatorsListTitle(preferredLanguages: selectedLocale.rLanguages)

            updateProceedButton(title: nil)

            rootView.searchTextField.textField.placeholder = R.string.localizable.manageAssetsSearchHint(
                preferredLanguages: selectedLocale.rLanguages
            )
        }
    }
}

// MARK: - CustomValidatorListViewProtocol

extension CustomValidatorListViewController: CustomValidatorListViewProtocol {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]? = nil) {
        title = viewModel.title

        cellViewModels = viewModel.cellViewModels
        headerViewModel = viewModel.headerViewModel
        selectedValidatorsCount = viewModel.selectedValidatorsCount
        selectedValidatorsLimit = viewModel.selectedValidatorsLimit ?? 0

        if let indexes = indexes {
            let indexPaths = indexes.map {
                IndexPath(row: $0, section: 0)
            }

            UIView.performWithoutAnimation {
                rootView.tableView.reloadRows(at: indexPaths, with: .automatic)
            }
        } else {
            rootView.tableView.reloadData()
        }

        updateProceedButton(title: viewModel.proceedButtonTitle)
    }

    func setFilterAppliedState(to applied: Bool) {
        filterIsApplied = applied
        updateSetFiltersButton()
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
        cell.delegate = self

        let viewModel = cellViewModels[indexPath.row]
        cell.bind(viewModel: viewModel)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension CustomValidatorListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let viewModel = cellViewModels[indexPath.row]

        presenter.changeValidatorSelection(address: viewModel.address)
    }
}

// MARK: - CustomValidatorCellDelegate

extension CustomValidatorListViewController: CustomValidatorCellDelegate {
    func didTapInfoButton(in cell: CustomValidatorCell) {
        if let indexPath = rootView.tableView.indexPath(for: cell) {
            let viewModel = cellViewModels[indexPath.row]
            presenter.didSelectValidator(address: viewModel.address)
        }
    }
}
