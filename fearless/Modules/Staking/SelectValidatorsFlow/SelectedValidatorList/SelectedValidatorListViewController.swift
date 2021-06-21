import UIKit
import SoraFoundation

final class SelectedValidatorListViewController: UIViewController, ViewHolder {
    typealias RootViewType = SelectedValidatorListViewLayout

    let presenter: SelectedValidatorListPresenterProtocol
    let selectedValidatorsLimit: Int

    private var headerView: SelectedValidatorListHeaderView?
    private var viewModel: SelectedValidatorListViewModel?

    // MARK: - Lifecycle

    init(
        presenter: SelectedValidatorListPresenterProtocol,
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
        view = SelectedValidatorListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        setupNavigationBar()
        setupProceedButton()

        applyLocalization()

        presenter.setup()
    }

    // MARK: - Private functions

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SelectedValidatorCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SelectedValidatorListHeaderView.self)
    }

    private func setupNavigationBar() {
        let rightBarButtonItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(tapEditButton)
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!,
            .font: UIFont.h5Title
        ]

        rightBarButtonItem.setTitleTextAttributes(attributes, for: .normal)
        rightBarButtonItem.setTitleTextAttributes(attributes, for: .highlighted)

        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    private func setupProceedButton() {
        rootView.proceedButton.addTarget(self, action: #selector(tapProceedButton), for: .touchUpInside)
        updateProceedButton()
    }

    private func updateEditButton() {
        if rootView.tableView.isEditing {
            navigationItem.rightBarButtonItem?.title = R.string.localizable
                .commonDone(preferredLanguages: selectedLocale.rLanguages)
        } else {
            navigationItem.rightBarButtonItem?.title = R.string.localizable
                .commonEdit(preferredLanguages: selectedLocale.rLanguages)
        }
    }

    private func updateProceedButton() {
        let cellViewModels = viewModel?.cellViewModels ?? []

        let buttonTitle: String
        let enabled: Bool
        let fillColor: UIColor

        if cellViewModels.count > selectedValidatorsLimit ||
            cellViewModels.isEmpty ||
            rootView.tableView.isEditing {
            enabled = false
            fillColor = R.color.colorDarkGray()!

        } else {
            enabled = true
            fillColor = R.color.colorAccent()!
        }

        buttonTitle = cellViewModels.count > selectedValidatorsLimit ?
            R.string.localizable
            .stakingCustomProceedButtonDisabledTitle(
                selectedValidatorsLimit,
                preferredLanguages: selectedLocale.rLanguages
            ) :
            R.string.localizable
            .commonContinue(
                preferredLanguages: selectedLocale.rLanguages
            )

        rootView.proceedButton.triangularedView?.fillColor = fillColor
        rootView.proceedButton.imageWithTitleView?.title = buttonTitle
        rootView.proceedButton.isEnabled = enabled
    }

    private func updateHeaderView() {
        guard let viewModel = viewModel else { return }
        headerView?.bind(
            viewModel: viewModel.headerViewModel,
            shouldAlert: viewModel.limitIsExceeded
        )
    }

    private func presentValidatorInfo(at index: Int) {
        presenter.didSelectValidator(at: index)
    }

    // MARK: - Actions

    @objc private func tapEditButton() {
        rootView.tableView.setEditing(
            !rootView.tableView.isEditing,
            animated: true
        )
        updateEditButton()
        updateProceedButton()
    }

    @objc private func tapProceedButton() {
        presenter.proceed()
    }
}

// MARK: - Localizable

extension SelectedValidatorListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .stakingSelectedValidatorsTitle(preferredLanguages: selectedLocale.rLanguages)

            updateEditButton()
            updateProceedButton()
            updateHeaderView()
        }
    }
}

// MARK: - SelectedValidatorListViewProtocol

extension SelectedValidatorListViewController: SelectedValidatorListViewProtocol {
    func updateViewModel(_ viewModel: SelectedValidatorListViewModel) {
        self.viewModel = viewModel
        updateHeaderView()
        updateProceedButton()
    }

    func reload(_ viewModel: SelectedValidatorListViewModel) {
        self.viewModel = viewModel
        updateProceedButton()
        rootView.tableView.reloadData()
    }

    func didRemoveItem(at index: Int) {
        let indexPath = IndexPath(row: index, section: 0)
        rootView.tableView.deleteRows(at: [indexPath], with: .left)
    }
}

// MARK: - UITableViewDataSource

extension SelectedValidatorListViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.cellViewModels.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCellWithType(SelectedValidatorCell.self)!

        let cellViewModel = viewModel.cellViewModels[indexPath.row]
        cell.bind(viewModel: cellViewModel)

        return cell
    }

    func tableView(
        _: UITableView,
        commit _: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        presenter.removeItem(at: indexPath.row)
    }
}

// MARK: - UITableViewDelegate

extension SelectedValidatorListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.didSelectValidator(at: indexPath.row)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let viewModel = viewModel else { return nil }

        let headerView: SelectedValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()
        self.headerView = headerView
        headerView.bind(
            viewModel: viewModel.headerViewModel,
            shouldAlert: viewModel.limitIsExceeded
        )

        return headerView
    }
}
