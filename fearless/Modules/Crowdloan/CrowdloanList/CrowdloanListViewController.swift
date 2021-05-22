import UIKit
import SoraFoundation
import SoraUI

final class CrowdloanListViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanListViewLayout

    let presenter: CrowdloanListPresenterProtocol

    let tokenSymbol: LocalizableResource<String>

    private var state: CrowdloanListState = .loading

    init(
        presenter: CrowdloanListPresenterProtocol,
        tokenSymbol: LocalizableResource<String>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.tokenSymbol = tokenSymbol

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CrowdloanListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()
    }

    func configure() {
        rootView.tableView.registerClassForCell(MultilineTableViewCell.self)
        rootView.tableView.registerClassForCell(YourCrowdloansTableViewCell.self)
        rootView.tableView.registerClassForCell(ActiveCrowdloanTableViewCell.self)
        rootView.tableView.registerClassForCell(CompletedCrowdloanTableViewCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CrowdloanStatusSectionView.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        title = R.string.localizable.tabbarCrowdloanTitle(preferredLanguages: languages)
    }

    private func applyState() {
        switch state {
        case .loading:
            rootView.tableView.isHidden = true
            didStartLoading()
        case .loaded:
            didStopLoading()
            rootView.tableView.isHidden = false
            rootView.tableView.reloadData()
        case .empty, .error:
            didStopLoading()
            rootView.tableView.isHidden = true
        }

        reloadEmptyState(animated: false)
    }
}

extension CrowdloanListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        switch state {
        case let .loaded(viewModel):
            if viewModel.active != nil, viewModel.completed != nil {
                return 3
            } else if viewModel.active != nil || viewModel.completed != nil {
                return 2
            } else {
                return 1
            }
        case .loading, .empty, .error:
            return 0
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        if section == 0 {
            return viewModel.contributionsCount != nil ? 2 : 1
        } else if section == 1 {
            return viewModel.active?.crowdloans.count ?? viewModel.completed?.crowdloans.count ?? 0
        } else {
            return viewModel.completed?.crowdloans.count ?? 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                let titleCell = tableView.dequeueReusableCellWithType(MultilineTableViewCell.self)!
                let symbol = tokenSymbol.value(for: selectedLocale)
                titleCell.bind(title: R.string.localizable.crowdloanListSectionFormat(symbol))
                return titleCell
            case 1:
                let yourCrowdloansCell = tableView.dequeueReusableCellWithType(YourCrowdloansTableViewCell.self)!
                let counter = viewModel.contributionsCount ?? ""
                yourCrowdloansCell.bind(details: counter, for: selectedLocale)
                return yourCrowdloansCell
            default:
                return UITableViewCell()
            }
        } else if indexPath.section == 1, let active = viewModel.active {
            return createActiveTableViewCell(
                tableView,
                viewModel: active.crowdloans[indexPath.row].content
            )
        }

        if let completed = viewModel.completed {
            return createCompletedTableViewCell(
                tableView,
                viewModel: completed.crowdloans[indexPath.row].content
            )
        }

        return UITableViewCell()
    }

    private func createActiveTableViewCell(
        _ tableView: UITableView,
        viewModel: ActiveCrowdloanViewModel
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(ActiveCrowdloanTableViewCell.self)!
        cell.bind(viewModel: viewModel)
        return cell
    }

    private func createCompletedTableViewCell(
        _ tableView: UITableView,
        viewModel: CompletedCrowdloanViewModel
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(CompletedCrowdloanTableViewCell.self)!
        cell.bind(viewModel: viewModel)
        return cell
    }
}

extension CrowdloanListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section > 0, case let .loaded(viewModel) = state else {
            return nil
        }

        let headerView: CrowdloanStatusSectionView = tableView.dequeueReusableHeaderFooterView()

        if section == 1, let active = viewModel.active {
            headerView.bind(title: active.title, status: .active)
        } else if let completed = viewModel.completed {
            headerView.bind(title: completed.title, status: .completed)
        }

        return headerView
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section > 0 ? 40.0 : 0.0
    }
}

extension CrowdloanListViewController: CrowdloanListViewProtocol {
    func didReceive(state: CrowdloanListState) {
        self.state = state

        applyState()
    }
}

extension CrowdloanListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension CrowdloanListViewController: LoadableViewProtocol {}

extension CrowdloanListViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension CrowdloanListViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        switch state {
        case let .error(message):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = message
            errorView.delegate = self
            return errorView
        case .empty:
            let emptyView = EmptyStateView()
            emptyView.image = R.image.iconEmptyHistory()
            emptyView.title = R.string.localizable
                .crowdloanEmptyMessage(preferredLanguages: selectedLocale.rLanguages)
            emptyView.titleColor = R.color.colorLightGray()!
            emptyView.titleFont = .p2Paragraph
            return emptyView
        case .loading, .loaded:
            return nil
        }
    }
}

extension CrowdloanListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        switch state {
        case .error, .empty:
            return true
        case .loading, .loaded:
            return false
        }
    }
}

extension CrowdloanListViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.refresh()
    }
}
