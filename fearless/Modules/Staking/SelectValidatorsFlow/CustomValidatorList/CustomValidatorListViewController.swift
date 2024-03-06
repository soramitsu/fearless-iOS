import UIKit
import SoraFoundation
import SoraUI

final class CustomValidatorListViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    private enum Constants {
        static let regularHeaderMargins = UIEdgeInsets(
            top: 16.0,
            left: 0.0,
            bottom: 8.0,
            right: 0.0
        )
    }

    typealias RootViewType = CustomValidatorListViewLayout

    let presenter: CustomValidatorListPresenterProtocol

    private var sections: [CustomValidatorListSectionViewModel]?
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
        rootView.tableView.rowHeight = UIConstants.validatorCellHeight
        rootView.tableView.separatorStyle = .none
        rootView.tableView.registerHeaderFooterView(
            withClass: YourValidatorListStatusSectionView.self
        )
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

    private func configureElected(headerView: YourValidatorListStatusSectionView, section: CustomValidatorListSectionViewModel) {
        headerView.statusView.titleLabel.textColor = R.color.colorWhite()
        headerView.bind(icon: section.icon, title: section.title, value: "")

        headerView.borderView.borderType = .none
        headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
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
            rootView.locale = selectedLocale
        }
    }
}

// MARK: - CustomValidatorListViewProtocol

extension CustomValidatorListViewController: CustomValidatorListViewProtocol {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]? = nil) {
        title = viewModel.title

        sections = viewModel.sections
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

        reloadEmptyState(animated: false)
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
    func numberOfSections(in _: UITableView) -> Int {
        (sections?.count).or(0)
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = sections?[section] else {
            return 0
        }

        return section.cells.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let section = sections?[indexPath.section]
        else {
            return UITableViewCell()
        }

        let viewModel = section.cells[indexPath.row]

        let cell = tableView.dequeueReusableCellWithType(CustomValidatorCell.self)!
        cell.delegate = self
        cell.bind(viewModel: viewModel)

        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = sections?[section] else {
            return nil
        }

        let headerView: YourValidatorListStatusSectionView = tableView.dequeueReusableHeaderFooterView()
        configureElected(headerView: headerView, section: section)
        return headerView
    }
}

// MARK: - UITableViewDelegate

extension CustomValidatorListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard
            let section = sections?[indexPath.section]
        else {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
        let viewModel = section.cells[indexPath.row]

        presenter.changeValidatorSelection(address: viewModel.address)
    }
}

// MARK: - CustomValidatorCellDelegate

extension CustomValidatorListViewController: CustomValidatorCellDelegate {
    func didTapInfoButton(in cell: CustomValidatorCell) {
        if
            let indexPath = rootView.tableView.indexPath(for: cell),
            let section = sections?[indexPath.section] {
            let viewModel = section.cells[indexPath.row]
            presenter.didSelectValidator(address: viewModel.address)
        }
    }
}

extension CustomValidatorListViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension CustomValidatorListViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard sections != nil else {
            return nil
        }

        let errorView = ErrorStateView()
        errorView.isUserInteractionEnabled = false
        errorView.errorDescriptionLabel.text = R.string.localizable.customValidatorsEmptyMessage(preferredLanguages: selectedLocale.rLanguages)
        errorView.locale = selectedLocale
        errorView.setRetryEnabled(false)
        errorView.setTitle(R.string.localizable.nftStubTitle(preferredLanguages: selectedLocale.rLanguages))
        return errorView
    }
}

extension CustomValidatorListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        sections?.isEmpty == true
    }
}
