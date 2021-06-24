import UIKit
import SoraFoundation
import SoraUI

final class ValidatorSearchViewController: UIViewController, ViewHolder {
    typealias RootViewType = ValidatorSearchViewLayout

    let presenter: ValidatorSearchPresenterProtocol

    private var viewModel: CustomValidatorListViewModel?

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

        presenter.setup()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        rootView.searchField.resignFirstResponder()
    }

    // MARK: - Private functions

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
        #warning("Not implemented")
        // TODO: Pass models back to presenting scene
    }
}

// MARK: - ValidatorSearchViewProtocol

extension ValidatorSearchViewController: ValidatorSearchViewProtocol {}

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

extension ValidatorSearchViewController: UITableViewDelegate {}

// MARK: - UITextFieldDelegate

extension ValidatorSearchViewController: UITextFieldDelegate {}

// MARK: - EmptyStateDataSource

extension ValidatorSearchViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        #warning("Not implemented")
        return UIView()
    }

    var imageForEmptyState: UIImage? {
        #warning("Not implemented")
        return UIImage()
    }

    var titleForEmptyState: String? {
        #warning("Not implemented")
        return ""
    }

    var titleColorForEmptyState: UIColor? {
        #warning("Not implemented")
        return .white
    }

    var titleFontForEmptyState: UIFont? {
        #warning("Not implemented")
        return .p0Paragraph
    }

    var verticalSpacingForEmptyState: CGFloat? {
        #warning("Not implemented")
        return 10.0
    }

    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        #warning("Not implemented")
        return .none
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
