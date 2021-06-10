import UIKit
import SoraFoundation

final class CustomValidatorListViewController: UIViewController, ViewHolder {
    typealias RootViewType = CustomValidatorListViewLayout

    let presenter: CustomValidatorListPresenterProtocol

    private var cellViewModels: [CustomValidatorCellViewModel] = []

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
        // rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CustomValidatorCell.self)
    }

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItems = [rootView.filterButton,
                                              rootView.searchButton]

        rootView.filterButton.target = self
        rootView.searchButton.target = self

        rootView.filterButton.action = #selector(tapFilterButton)
        rootView.searchButton.action = #selector(tapSearchButton)
    }

    private func setupActionButtons() {
        rootView.fillRestButton.addTarget(self, action: #selector(tapFillRestButton), for: .touchUpInside)
        rootView.clearButton.addTarget(self, action: #selector(tapClearButton), for: .touchUpInside)
        rootView.deselectButton.addTarget(self, action: #selector(tapDeselectButton), for: .touchUpInside)
        rootView.proceedButton.addTarget(self, action: #selector(tapProceedButton), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc
    private func handleValidatorInfo() {
        // TODO: handle right validator info
        presenter.didSelectValidator(at: 0)
    }

    @objc private func tapFilterButton() {
        #warning("Not implemented")
    }

    @objc private func tapSearchButton() {
        #warning("Not implemented")
    }

    @objc private func tapFillRestButton() {
        #warning("Not implemented")
    }

    @objc private func tapClearButton() {
        #warning("Not implemented")
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

            rootView.fillRestButton.imageWithTitleView?.title = "Fill rest with recommended".uppercased()
            rootView.clearButton.imageWithTitleView?.title = "Clear filters".uppercased()
            rootView.deselectButton.imageWithTitleView?.title = "Deselect all".uppercased()

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
