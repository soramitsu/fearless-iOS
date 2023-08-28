import UIKit
import SoraFoundation
import SoraUI

final class MainNftContainerViewController: UIViewController, ViewHolder {
    typealias RootViewType = MainNftContainerViewLayout

    // MARK: Private properties

    private let output: MainNftContainerViewOutput
    private var viewModels: [NftListCellModel]?
    private var history: [NFTHistoryObject]?

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
    }

    // MARK: - Private methods
}

// MARK: - MainNftContainerViewInput

extension MainNftContainerViewController: MainNftContainerViewInput {
    func didReceive(viewModels: [NftListCellModel]) {
        self.viewModels = viewModels
        rootView.tableView.reloadData()

        reloadEmptyState(animated: true)
    }

    func didReceive(history: [NFTHistoryObject]) {
        self.history = history
        rootView.tableView.reloadData()
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

        if let history = history {
            return history.count
        }

        return 10
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(NftListCell.self)
        return cell ?? UITableViewCell()
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let nftCell = cell as? NftListCell else {
            return
        }
        let viewModel = viewModels?[safe: indexPath.row]
        nftCell.bind(viewModel: viewModel)
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
        let emptyView = EmptyStateView()

        if viewModels != nil {
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
        rootView
    }

    var verticalSpacingForEmptyState: CGFloat? {
        26.0
    }
}

// MARK: - EmptyStateDelegate

extension MainNftContainerViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModels = viewModels else { return true }
        return viewModels.isEmpty
    }
}
