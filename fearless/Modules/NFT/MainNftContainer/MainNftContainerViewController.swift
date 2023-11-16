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

        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self
        rootView.collectionView.registerClassForCell(NftCollectionCell.self)

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(self, action: #selector(actionRefresh), for: .valueChanged)
        }
        if let collectionRefreshControl = rootView.collectionView.refreshControl {
            collectionRefreshControl.addTarget(self, action: #selector(actionRefresh), for: .valueChanged)
        }

        rootView.nftContentControl.filterButton.addTarget(
            self,
            action: #selector(filterButtonClicked),
            for: .touchUpInside
        )

        rootView.nftContentControl.collectionButton.addTarget(
            self,
            action: #selector(collectionButtonClicked),
            for: .touchUpInside
        )

        rootView.nftContentControl.tableButton.addTarget(
            self,
            action: #selector(tableButtonClicked),
            for: .touchUpInside
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewAppeared()
    }

    // MARK: - Private methods

    @objc private func actionRefresh() {
        viewModels = nil
        rootView.tableView.reloadData()
        rootView.collectionView.reloadData()
        output.didPullToRefresh()
        rootView.tableView.refreshControl?.endRefreshing()
        rootView.collectionView.refreshControl?.endRefreshing()
    }

    @objc private func filterButtonClicked() {
        output.didTapFilterButton()
    }

    @objc private func collectionButtonClicked() {
        output.didTapCollectionButton()
        rootView.bind(appearance: .collection)
    }

    @objc private func tableButtonClicked() {
        output.didTapTableButton()
        rootView.bind(appearance: .table)
    }
}

// MARK: - MainNftContainerViewInput

extension MainNftContainerViewController: MainNftContainerViewInput {
    func didReceive(viewModels: [NftListCellModel]?) {
        self.viewModels = viewModels
        rootView.tableView.reloadData()
        rootView.collectionView.reloadData()

        reloadEmptyState(animated: true)
    }

    func didReceive(appearance: NftCollectionAppearance) {
        rootView.bind(appearance: appearance)
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

extension MainNftContainerViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        let flowayout = collectionViewLayout as? UICollectionViewFlowLayout
        let space: CGFloat = (flowayout?.minimumInteritemSpacing ?? 0.0) + (flowayout?.sectionInset.left ?? 0.0) + (flowayout?.sectionInset.right ?? 0.0)
        let size: CGFloat = (rootView.collectionView.frame.size.width - space) / 2.0
        return CGSize(width: size, height: 233)
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        if let viewModels = viewModels {
            return viewModels.count
        }

        return 10
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(NftCollectionCell.self, forIndexPath: indexPath)
        if let cellModel = viewModels?[safe: indexPath.item] {
            cell.bind(cellModel: cellModel)
        }
        return cell
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let viewModel = viewModels?[safe: indexPath.item] else {
            return
        }

        output.didSelect(collection: viewModel.collection)
    }

    func collectionView(_: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let nftCell = cell as? NftCollectionCell else {
            return
        }
        let viewModel = viewModels?[safe: indexPath.row]
        nftCell.bind(cellModel: viewModel)
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
