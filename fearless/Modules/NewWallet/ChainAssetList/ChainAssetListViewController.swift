import UIKit
import SoraFoundation
import SnapKit
import SoraUI
import SCard

enum HiddenSectionState {
    case hidden
    case expanded
    case empty
}

final class ChainAssetListViewController:
    UIViewController,
    ViewHolder,
    KeyboardViewAdoptable {
    enum Constants {
        static let sectionHeaderHeight: CGFloat = 80
    }

    typealias RootViewType = ChainAssetListViewLayout

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let output: ChainAssetListViewOutput

    private weak var bannersViewController: UIViewController?

    private var viewModel: ChainAssetListViewModel?
    private var hiddenSectionState: HiddenSectionState = .expanded
    private lazy var locale: Locale = {
        localizationManager?.selectedLocale ?? Locale.current
    }()

    // MARK: - Constructor

    init(
        bannersViewController: UIViewController?,
        output: ChainAssetListViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.bannersViewController = bannersViewController
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
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

private extension ChainAssetListViewController {
    func configureTableView() {
        rootView.tableView.registerClassForCell(SCCardCell.self)
        rootView.tableView.registerClassForCell(ChainAccountBalanceTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        if #available(iOS 15.0, *) {
            rootView.tableView.sectionHeaderTopPadding = 0
        }
    }

    func cellViewModel(for indexPath: IndexPath) -> ChainAccountBalanceCellViewModel? {
        if
            let section = viewModel?.sections[indexPath.section],
            let cellModel = viewModel?.cellsForSections[section]?[indexPath.row] {
            return cellModel
        }
        return nil
    }

    func expandHiddenSection() {
        switch hiddenSectionState {
        case .expanded:
            hiddenSectionState = .hidden
        case .hidden:
            hiddenSectionState = .expanded
        case .empty:
            hiddenSectionState = .empty
        }
        output.didTapExpandSections(state: hiddenSectionState)
        rootView.tableView.reloadData()
    }

    func setupEmbededViews() {
        guard let bannersViewController = bannersViewController else {
            return
        }

        addChild(bannersViewController)

        rootView.addBanners(view: bannersViewController.view)
        bannersViewController.didMove(toParent: self)
    }
}

// MARK: - ChainAssetListViewInput

extension ChainAssetListViewController: ChainAssetListViewInput {
    func closeSoraCard() {
        rootView.closeSoraCard()
    }

    func reloadBanners() {
        guard viewModel != nil else {
            return
        }
        rootView.tableView.beginUpdates()
        rootView.tableView.setAndLayoutTableHeaderView(header: rootView.headerViewContainer)
        rootView.tableView.endUpdates()
    }

    func didReceive(viewModel: ChainAssetListViewModel) {
        UIView.animate(withDuration: 0.3) {
            self.rootView.bannersView?.isHidden = viewModel.bannerIsHidden
        }
        let isInitialReload = self.viewModel == nil

        self.viewModel = viewModel
        hiddenSectionState = viewModel.hiddenSectionState
        if let soraItem = viewModel.soraCardItem {
            rootView.bindSoraCard(item: soraItem, isHidden: viewModel.soraCardHidden)
        }

        if isInitialReload {
            rootView.tableView.reloadData()
        } else {
            let debounce = debounce(delay: DispatchTimeInterval.milliseconds(250)) { [weak self] in
                self?.rootView.tableView.reloadData()
                self?.reloadEmptyState(animated: false)
            }
            debounce()
        }
    }
}

// MARK: - Localizable

extension ChainAssetListViewController: Localizable {
    func applyLocalization() {}
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

extension ChainAssetListViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = cellViewModel(for: indexPath) else { return }

        output.didSelectViewModel(viewModel)
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 1 {
            let view = HiddenSectionHeader()
            switch hiddenSectionState {
            case .expanded:
                view.imageView.image = R.image.iconExpandable()
            case .hidden:
                view.imageView.image = R.image.iconExpandableInverted()
            case .empty:
                return nil
            }
            let sectionViewModel = HiddenSectionViewModel(
                title: R.string.localizable.hiddenAssets(preferredLanguages: locale.rLanguages),
                expandTapHandler: { [weak self] in
                    self?.expandHiddenSection()
                }
            )
            view.bind(viewModel: sectionViewModel)
            return view
        }
        return nil
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 1 {
            switch hiddenSectionState {
            case .expanded, .hidden:
                return Constants.sectionHeaderHeight
            case .empty:
                return 0
            }
        }
        return 0
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let sect = viewModel?.sections[indexPath.section],
           let cells = viewModel?.cellsForSections[sect],
           let assetCell = cell as? ChainAccountBalanceTableCell,
           let viewModel = cells[safe: indexPath.row] {
            assetCell.bind(to: viewModel)
        }
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        ChainAccountBalanceTableCell.LayoutConstants.cellHeight
    }
}

extension ChainAssetListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel?.sections.count ?? 0
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let sect = viewModel?.sections[section],
           let cells = viewModel?.cellsForSections[sect] {
            if case ChainAssetListTableSection.hidden.rawValue = section, hiddenSectionState == .hidden {
                return 0
            }
            return cells.count
        }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ChainAccountBalanceTableCell.reuseIdentifier,
            for: indexPath
        ) as? ChainAccountBalanceTableCell else {
            return UITableViewCell()
        }
        cell.delegate = self
        return cell
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
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarningGray()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.text = R.string.localizable.emptyViewDescription(preferredLanguages: selectedLocale.rLanguages)
        emptyView.iconMode = .smallFilled
        emptyView.contentAlignment = ContentAlignment(vertical: .top, horizontal: .center)
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView
    }
}

// MARK: - EmptyStateDelegate

extension ChainAssetListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModel = viewModel else { return false }
        return viewModel.emptyStateIsActive
    }
}
