import UIKit
import SoraFoundation
import SoraUI

final class MainNftContainerViewController: UIViewController, ViewHolder {
    enum LayoutConstants {
        static var tabBarHeight: CGFloat = 83.0
    }

    typealias RootViewType = MainNftContainerViewLayout

    // MARK: Private properties

    private let output: MainNftContainerViewOutput
    private var viewModels: [NftNetworkSectionModel]?

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
        rootView.collectionView.register(
            NftNetworkCollectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: NftNetworkCollectionHeader.reuseID
        )

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(self, action: #selector(actionRefresh), for: .valueChanged)
        }

        let collectionRefreshControl = UIRefreshControl()
        collectionRefreshControl.addTarget(self, action: #selector(actionRefresh), for: .valueChanged)
        rootView.collectionView.refreshControl = collectionRefreshControl

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
    func didReceive(viewModels: [NftNetworkSectionModel]?) {
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
    func numberOfSections(in _: UITableView) -> Int {
        viewModels?.count ?? 1
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let viewModels = viewModels {
            return viewModels[safe: section]?.items.count ?? 0
        }

        return 10
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        viewModels?[safe: section]?.networkTitle
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(NftListCell.self, forIndexPath: indexPath)
        return cell
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let nftCell = cell as? NftListCell else {
            return
        }
        let viewModel = viewModels?[safe: indexPath.section]?.items[safe: indexPath.row]
        nftCell.bind(viewModel: viewModel)
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cellModel = viewModels?[safe: indexPath.section]?.items[safe: indexPath.row] else {
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

    func numberOfSections(in _: UICollectionView) -> Int {
        viewModels?.count ?? 1
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let viewModels = viewModels {
            return viewModels[safe: section]?.items.count ?? 0
        }

        return 10
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(NftCollectionCell.self, forIndexPath: indexPath)
        if let cellModel = viewModels?[safe: indexPath.section]?.items[safe: indexPath.item] {
            cell.bind(cellModel: cellModel)
        }
        return cell
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let viewModel = viewModels?[safe: indexPath.section]?.items[safe: indexPath.item] else {
            return
        }

        output.didSelect(collection: viewModel.collection)
    }

    func collectionView(_: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let nftCell = cell as? NftCollectionCell else {
            return
        }
        let viewModel = viewModels?[safe: indexPath.section]?.items[safe: indexPath.row]
        nftCell.bind(cellModel: viewModel)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: NftNetworkCollectionHeader.reuseID,
            for: indexPath
        ) as? NftNetworkCollectionHeader
        header?.bind(title: viewModels?[safe: indexPath.section]?.networkTitle)
        return header ?? UICollectionReusableView()
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        viewModels?[safe: section] == nil ? .zero : CGSize(width: 1, height: 38)
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
        emptyView.image = R.image.iconWarning()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.text = R.string.localizable
            .nftListEmptyMessage(preferredLanguages: selectedLocale.rLanguages)
        emptyView.iconMode = .bigFilledShadow
        emptyView.verticalOffset = -LayoutConstants.tabBarHeight
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.emptyViewContainer
    }
}

// MARK: - EmptyStateDelegate

extension MainNftContainerViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModels = viewModels else { return false }
        return viewModels.flatMap(\.items).isEmpty
    }
}

final class NftNetworkCollectionHeader: UICollectionReusableView {
    static let reuseID = "NftNetworkCollectionHeader"
    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = R.color.colorWhite() ?? .white
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(title: String?) {
        label.text = title
    }
}
