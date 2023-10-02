import UIKit
import SoraFoundation
import SoraUI

final class MainNftContainerViewController: UIViewController, ViewHolder {
    typealias RootViewType = MainNftContainerViewLayout

    // MARK: Private properties

    private let output: MainNftContainerViewOutput
    private var viewModels: [NftListCellModel]?

    // MARK: - Constructor

    init(
        output: MainNftContainerViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = MainNftContainerViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(NftListCell.self)

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(self, action: #selector(actionRefresh), for: .valueChanged)
        }
    }

    // MARK: - Private methods

    @objc private func actionRefresh() {
        viewModels = nil
        rootView.tableView.reloadData()
        output.didPullToRefresh()
        rootView.tableView.refreshControl?.endRefreshing()
    }
}

// MARK: - MainNftContainerViewInput

extension MainNftContainerViewController: MainNftContainerViewInput {
    func didReceive(viewModels: [NftListCellModel]?) {
        self.viewModels = viewModels
        rootView.tableView.reloadData()

        reloadEmptyState(animated: true)
    }
}

// MARK: - Localizable

extension MainNftContainerViewController: Localizable {
    func applyLocalization() {}
}

extension MainNftContainerViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        if let viewModels = viewModels {
            return viewModels.count
        }

        return 10
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(NftListCell.self, forIndexPath: indexPath)
        return cell
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let nftCell = cell as? NftListCell else {
            return
        }
        let viewModel = viewModels?[safe: indexPath.row]
        nftCell.bind(viewModel: viewModel)
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cellModel = viewModels?[safe: indexPath.row] else {
            return
        }

        output.didSelect(collection: cellModel.collection)
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension MainNftContainerViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension MainNftContainerViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarningGray()
        emptyView.title = R.string.localizable
            .importEmptyDerivationConfirm(preferredLanguages: selectedLocale.rLanguages)
        emptyView.iconMode = .smallFilled
        emptyView.contentAlignment = ContentAlignment(vertical: .center, horizontal: .center)
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView
    }

    var verticalSpacingForEmptyState: CGFloat? {
        26.0
    }
}

// MARK: - EmptyStateDelegate

extension MainNftContainerViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModels = viewModels else { return false }
        return viewModels.isEmpty
    }
}
