import UIKit
import SoraFoundation
import SnapKit
import SoraUI
import SSFModels

final class ChainAssetListViewController:
    UIViewController,
    ViewHolder,
    KeyboardViewAdoptable {
    typealias RootViewType = ChainAssetListViewLayout

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let output: ChainAssetListViewOutput

    private weak var bannersViewController: UIViewController?
    private let keyboardAdoptable: Bool

    private var viewModel: ChainAssetListViewModel?
    private var collapsedNetworkSectionIds: Set<String> = []
    private lazy var locale: Locale = {
        localizationManager?.selectedLocale ?? Locale.current
    }()

    // MARK: - Constructor

    init(
        bannersViewController: UIViewController?,
        output: ChainAssetListViewOutput,
        keyboardAdoptable: Bool,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.bannersViewController = bannersViewController
        self.keyboardAdoptable = keyboardAdoptable
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
        view = ChainAssetListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configureTableView()
        setupEmbededViews()
        bindActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil, keyboardAdoptable {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - KeyboardViewAdoptable

    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { 0 }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - Private methods

private extension ChainAssetListViewController {
    func configureTableView() {
        rootView.tableView.registerClassForCell(ChainAccountBalanceTableCell.self)
        rootView.tableView.register(
            AssetNetworkHeaderView.self,
            forHeaderFooterViewReuseIdentifier: AssetNetworkHeaderView.reuseId
        )
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.estimatedRowHeight = 93

        if #available(iOS 15.0, *) {
            rootView.tableView.sectionHeaderTopPadding = 0
        }

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(
                self,
                action: #selector(handlePullToRefresh),
                for: .valueChanged
            )
        }
    }

    func cellViewModel(for indexPath: IndexPath) -> ChainAccountBalanceCellViewModel? {
        if let section = viewModel?.networkSections[safe: indexPath.section] {
            return section.rows[safe: indexPath.row]
        }

        return viewModel?.displayState.rows[safe: indexPath.row]
    }

    func setupEmbededViews() {
        guard let bannersViewController = bannersViewController else {
            return
        }

        addChild(bannersViewController)

        rootView.addBanners(view: bannersViewController.view)
        bannersViewController.didMove(toParent: self)
    }

    func bindActions() {
        rootView.footerButton.addAction { [weak self] in
            guard let self, let viewModel = self.viewModel else {
                return
            }
            switch viewModel.displayState {
            case .defaultList, .allIsHidden:
                self.output.didTapManageAsset()
            case let .chainHasNetworkIssue(chain):
                self.rootView.footerButton.set(loading: true)
                self.output.didTapResolveNetworkIssue(for: chain)
            case let .chainHasAccountIssue(chain):
                self.output.didTapResolveAccountIssue(for: chain)
            case .search:
                break
            }
        }
    }

    @objc func handlePullToRefresh() {
        output.didPullToRefresh()
        rootView.tableView.refreshControl?.endRefreshing()
    }
}

// MARK: - ChainAssetListViewInput

extension ChainAssetListViewController: ChainAssetListViewInput {
    func reloadBanners() {
        guard viewModel != nil else {
            return
        }
        rootView.tableView.setAndLayoutTableHeaderView(header: rootView.headerViewContainer)
    }

    func didReceive(viewModel: ChainAssetListViewModel) {
        self.viewModel = viewModel
        rootView.setFooterButtonTitle(for: viewModel.displayState)
        rootView.footerButton.isHidden = viewModel.displayState.isSearch
        rootView.bannersView?.isHidden = viewModel.displayState.isSearch
        rootView.footerButton.set(loading: false)

        switch viewModel.displayState {
        case let .defaultList(_, withAnimate):
            rootView.setHeaderView()
            rootView.setFooterView()
            guard rootView.isAnimating == false else {
                return
            }

            rootView.tableView.reloadData()

            if withAnimate {
                rootView.runManageAssetAnimate(finish: { [weak self] in
                    self?.output.didFinishManageAssetAnimate()
                    self?.rootView.tableView.reloadData()
                })
            }
        case .chainHasNetworkIssue, .chainHasAccountIssue, .allIsHidden:
            rootView.removeHeaderView()
            rootView.removeFooterView()
            rootView.tableView.reloadData()
        case .search:
            let isEmpty = viewModel.displayState.rows.isEmpty
            isEmpty ? rootView.removeFooterView() : rootView.setFooterView()
            isEmpty ? rootView.removeHeaderView() : rootView.setHeaderView()
            rootView.tableView.reloadData()
        }
        reloadEmptyState(animated: false)
    }
}

// MARK: - Localizable

extension ChainAssetListViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension ChainAssetListViewController: SwipableTableViewCellDelegate {
    func swipeCellDidTap(on actionType: SwipableCellButtonType, with indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            return
        }
        if let viewModelForAction = cellViewModel(for: indexPath) {
            output.didTapAction(actionType: actionType, viewModel: viewModelForAction)
        }
    }
}

// MARK: - UITableViewDelegate

extension ChainAssetListViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = cellViewModel(for: indexPath) else { return }

        output.didSelectViewModel(viewModel)
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if
            let assetCell = cell as? ChainAccountBalanceTableCell,
            let viewModel = cellViewModel(for: indexPath) {
            assetCell.bind(to: viewModel)
        }
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        ChainAccountBalanceTableCell.LayoutConstants.cellHeight
    }

    func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        93
    }
}

// MARK: - UITableViewDataSource

extension ChainAssetListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        max(viewModel?.networkSections.count ?? 0, 1)
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let networkSection = viewModel?.networkSections[safe: section] else {
            return viewModel?.displayState.rows.count ?? .zero
        }

        return collapsedNetworkSectionIds.contains(networkSection.id) ? 0 : networkSection.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(ChainAccountBalanceTableCell.self) else {
            return UITableViewCell()
        }
        cell.delegate = self
        return cell
    }
}

private extension ChainAssetListViewController {
    func networkSection(at index: Int) -> AssetNetworkSectionViewModel? {
        viewModel?.networkSections[safe: index]
    }
}

extension ChainAssetListViewController {
    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        networkSection(at: section) == nil ? .leastNormalMagnitude : 72
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard
            let sectionModel = networkSection(at: section),
            let header = tableView.dequeueReusableHeaderFooterView(
                withIdentifier: AssetNetworkHeaderView.reuseId
            ) as? AssetNetworkHeaderView
        else {
            return nil
        }

        header.bind(
            sectionModel,
            collapsed: collapsedNetworkSectionIds.contains(sectionModel.id)
        )
        header.onTap = { [weak self] in
            guard let self else {
                return
            }

            if self.collapsedNetworkSectionIds.contains(sectionModel.id) {
                self.collapsedNetworkSectionIds.remove(sectionModel.id)
            } else {
                self.collapsedNetworkSectionIds.insert(sectionModel.id)
            }
            tableView.reloadSections(IndexSet(integer: section), with: .automatic)
        }
        return header
    }
}

private final class AssetNetworkHeaderView: UITableViewHeaderFooterView {
    static let reuseId = "AssetNetworkHeaderView"

    var onTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let subtotalLabel = UILabel()
    private let chevronView = UIImageView()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        contentView.backgroundColor = R.color.colorBlack19()
        titleLabel.font = .h5Title
        titleLabel.textColor = R.color.colorWhite()
        detailLabel.font = .p2Paragraph
        detailLabel.textColor = R.color.colorLightGray()
        subtotalLabel.font = .h6Title
        subtotalLabel.textColor = R.color.colorWhite()
        subtotalLabel.textAlignment = .right
        chevronView.tintColor = R.color.colorLightGray()

        let labels = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        labels.axis = .vertical
        labels.spacing = 3

        contentView.addSubview(labels)
        contentView.addSubview(subtotalLabel)
        contentView.addSubview(chevronView)

        labels.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(subtotalLabel.snp.leading).offset(-8)
        }
        chevronView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(14)
        }
        subtotalLabel.snp.makeConstraints { make in
            make.trailing.equalTo(chevronView.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        contentView.addGestureRecognizer(tapGesture)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTap = nil
    }

    func bind(_ viewModel: AssetNetworkSectionViewModel, collapsed: Bool) {
        switch viewModel.kind {
        case .assets:
            titleLabel.text = "\(viewModel.networkName) · \(viewModel.ecosystemName)"
            let address = viewModel.address.map { String($0.prefix(8)) + "…" }
            var details = [address, viewModel.syncStatus].compactMap { $0 }
            if viewModel.detectedCount > 0 {
                details.append(
                    String(
                        format: NSLocalizedString(
                            "portfolio.asset.detected_count",
                            value: "Detected assets (%d)",
                            comment: ""
                        ),
                        viewModel.detectedCount
                    )
                )
            }
            detailLabel.text = details.joined(separator: " · ")
            subtotalLabel.text = viewModel.fiatSubtotal ?? NSLocalizedString(
                "portfolio.price.unavailable",
                value: "Price unavailable",
                comment: ""
            )
        case .detected:
            titleLabel.text = String(
                format: NSLocalizedString(
                    "portfolio.asset.detected_count",
                    value: "Detected assets (%d)",
                    comment: ""
                ),
                viewModel.detectedCount
            )
            detailLabel.text = "\(viewModel.networkName) · " + NSLocalizedString(
                "portfolio.asset.detected_review",
                value: "Review before trusting",
                comment: ""
            )
            subtotalLabel.text = NSLocalizedString("portfolio.asset.review", value: "Review", comment: "")
        }
        chevronView.image = UIImage(systemName: collapsed ? "chevron.down" : "chevron.up")
    }

    @objc private func didTap() {
        onTap?()
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension ChainAssetListViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension ChainAssetListViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let viewModel else {
            return nil
        }
        let view = rootView.viewForEmptyState(for: viewModel.displayState)
        return view
    }

    var contentViewForEmptyState: UIView {
        rootView.containerView
    }
}

// MARK: - EmptyStateDelegate

extension ChainAssetListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModel = viewModel else { return false }
        return viewModel.displayState.rows.isEmpty
    }
}
