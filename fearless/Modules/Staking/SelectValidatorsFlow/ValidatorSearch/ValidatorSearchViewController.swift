import UIKit
import SoraFoundation
import SoraUI

final class ValidatorSearchViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = ValidatorSearchViewLayout

    let presenter: ValidatorSearchPresenterProtocol

    private var viewModel: ValidatorSearchViewModel?

    private lazy var searchActivityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .white)
        activityIndicator.color = .white
        return activityIndicator
    }()

    // MARK: - Lifecycle

    init(
        presenter: ValidatorSearchPresenterProtocol,
        localizationManager: LocalizationManager
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
        view = ValidatorSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        setupNavigationBar()
        setupSearchView()

        applyLocalization()
        applyState()

        presenter.setup()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        rootView.searchField.resignFirstResponder()
    }

    // MARK: - Private functions

    private func applyState() {
        rootView.tableView.isHidden = shouldDisplayEmptyState
        reloadEmptyState(animated: false)
    }

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CustomValidatorCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CustomValidatorListHeaderView.self)
    }

    private func setupNavigationBar() {
        let rightBarButtonItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(tapDoneButton)
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!,
            .font: UIFont.p0Paragraph
        ]

        rightBarButtonItem.setTitleTextAttributes(attributes, for: .normal)
        rightBarButtonItem.setTitleTextAttributes(attributes, for: .highlighted)

        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    private func setupSearchView() {
        rootView.searchField.delegate = self
    }

    private func presentValidatorInfo(at index: Int) {
        presenter.didSelectValidator(at: index)
    }

    // MARK: - Actions

    @objc private func tapDoneButton() {
        presenter.applyChanges()
    }
}

// MARK: - ValidatorSearchViewProtocol

extension ValidatorSearchViewController: ValidatorSearchViewProtocol {
    func didReload(_ viewModel: ValidatorSearchViewModel) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()

        applyState()
    }

    func didStartSearch() {
        rootView.searchField.rightViewMode = .always
        rootView.searchField.rightView = searchActivityIndicator
        searchActivityIndicator.startAnimating()
    }

    func didStopSearch() {
        searchActivityIndicator.stopAnimating()
        rootView.searchField.rightView = nil
    }

    func didReset() {
        viewModel = nil
        applyState()
    }
}

// MARK: - UITableViewDataSource

extension ValidatorSearchViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.cellViewModels.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellViewModels = viewModel?.cellViewModels else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCellWithType(CustomValidatorCell.self)!
        cell.delegate = self

        let viewModel = cellViewModels[indexPath.row]
        cell.bind(viewModel: viewModel)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension ValidatorSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.changeValidatorSelection(at: indexPath.row)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard viewModel?.headerViewModel != nil else { return 0 }
        return 26.0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let headerViewModel = viewModel?.headerViewModel else { return nil }
        let headerView: CustomValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(viewModel: headerViewModel)
        return headerView
    }
}

// MARK: - UITextFieldDelegate

extension ValidatorSearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        guard let text = textField.text else { return false }

        presenter.search(for: text)
        return false
    }

    func textFieldShouldClear(_: UITextField) -> Bool {
        presenter.search(for: "")
        return true
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let text = textField.text as NSString? else {
            return true
        }

        let newString = text.replacingCharacters(in: range, with: string)
        presenter.search(for: newString)

        return true
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension ValidatorSearchViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension ValidatorSearchViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyStateView()

        if viewModel != nil {
            emptyView.image = R.image.iconEmptySearch()
            emptyView.title = R.string.localizable
                .stakingValidatorSearchEmptyTitle(preferredLanguages: selectedLocale.rLanguages)
        } else {
            emptyView.image = R.image.iconStartSearch()
            emptyView.title = R.string.localizable
                .commonSearchStartTitle(preferredLanguages: selectedLocale.rLanguages)
        }

        emptyView.titleColor = R.color.colorLightGray()!
        emptyView.titleFont = .p2Paragraph
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.emptyStateContainer
    }

    var verticalSpacingForEmptyState: CGFloat? {
        26.0
    }
}

// MARK: - EmptyStateDelegate

extension ValidatorSearchViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModel = viewModel else { return true }
        return viewModel.cellViewModels.isEmpty
    }
}

// MARK: - CustomValidatorCellDelegate

extension ValidatorSearchViewController: CustomValidatorCellDelegate {
    func didTapInfoButton(in cell: CustomValidatorCell) {
        if let indexPath = rootView.tableView.indexPath(for: cell) {
            presentValidatorInfo(at: indexPath.row)
        }
    }
}

// MARK: - Localizable

extension ValidatorSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .commonSearch(preferredLanguages: selectedLocale.rLanguages)

            rootView.searchField.placeholder = R.string.localizable
                .stakingValidatorSearchPlaceholder(preferredLanguages: selectedLocale.rLanguages)

            navigationItem.rightBarButtonItem?.title = R.string.localizable
                .commonDone(preferredLanguages: selectedLocale.rLanguages)
        }
    }
}
