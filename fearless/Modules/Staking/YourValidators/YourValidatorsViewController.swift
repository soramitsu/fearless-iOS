import UIKit
import SoraFoundation
import SoraUI

final class YourValidatorsViewController: UIViewController, ViewHolder {
    typealias RootViewType = YourValidatorsViewLayout

    var presenter: YourValidatorsPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private var viewState: YourValidatorsViewState?

    init(presenter: YourValidatorsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle -

    override func loadView() {
        view = YourValidatorsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupTableView()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingYourValidatorsTitle(preferredLanguages: selectedLocale.rLanguages)

        navigationItem.rightBarButtonItem?.title = R.string.localizable
            .commonChange(preferredLanguages: selectedLocale.rLanguages)
    }

    private func setupNavigationItem() {
        let resetItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(actionChange)
        )

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!,
            .font: UIFont.p0Paragraph
        ]

        let highlightedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!.withAlphaComponent(0.5),
            .font: UIFont.p0Paragraph
        ]

        resetItem.setTitleTextAttributes(normalAttributes, for: .normal)
        resetItem.setTitleTextAttributes(highlightedAttributes, for: .highlighted)

        navigationItem.rightBarButtonItem = resetItem
    }

    private func setupTableView() {
        rootView.tableView.registerClassesForCell([
            YourValidatorTableCell.self
        ])

        rootView.tableView.registerHeaderFooterView(
            withClass: YourValidatorStatusSectionView.self
        )

        rootView.tableView.rowHeight = 48

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    @objc func actionChange() {
        presenter.changeValidators()
    }
}

// MARK: - UITableViewDataSource

extension YourValidatorsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard let sections = viewState?.validatorSections else {
            return 0
        }

        return sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = viewState?.validatorSections else {
            return 0
        }

        return sections[section].validators.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(YourValidatorTableCell.self)!

        let section = viewState?.validatorSections?[indexPath.section]
        let validator = section!.validators[indexPath.row]

        cell.bind(viewModel: validator, for: selectedLocale)

        return cell
    }
}

// MARK: UITableViewDelegate

extension YourValidatorsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = viewState?.validatorSections?[indexPath.section] else {
            return
        }

        presenter.didSelectValidator(viewModel: section.validators[indexPath.row])
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = viewState?.validatorSections?[section] else {
            return nil
        }

        let headerView: YourValidatorStatusSectionView = tableView.dequeueReusableHeaderFooterView()

        let title = section.title?.value(for: selectedLocale)
        let description = section.description?.value(for: selectedLocale)

        headerView.bind(title: title, description: description, for: section.status)

        return headerView
    }
}

extension YourValidatorsViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.retry()
    }
}

extension YourValidatorsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension YourValidatorsViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let state = viewState else { return nil }

        switch state {
        case let .error(error):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = error.value(for: selectedLocale)
            errorView.delegate = self
            return errorView
        case .loading, .validatorList:
            return nil
        }
    }
}

extension YourValidatorsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let state = viewState else { return false }
        switch state {
        case .error:
            return true
        case .loading, .validatorList:
            return false
        }
    }
}

extension YourValidatorsViewController: YourValidatorsViewProtocol {
    func reload(state: YourValidatorsViewState) {
        viewState = state

        if case .loading = viewState {
            didStartLoading()
        } else {
            didStopLoading()
        }

        rootView.tableView.reloadData()
        reloadEmptyState(animated: true)
    }
}

extension YourValidatorsViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
        }
    }
}
