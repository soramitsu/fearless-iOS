import UIKit
import SoraFoundation
import SnapKit

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

    // MARK: Private properties

    private let soraCardViewController: UIViewController?
    private let output: ChainAssetListViewOutput

    private var viewModel: ChainAssetListViewModel?
    private var hiddenSectionState: HiddenSectionState = .expanded
    private lazy var locale: Locale = {
        localizationManager?.selectedLocale ?? Locale.current
    }()

    // MARK: - Constructor

    init(
        output: ChainAssetListViewOutput,
        soraCardViewController: UIViewController?,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        self.soraCardViewController = soraCardViewController
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    private func setupEmbededSoraCardView() {
        guard let soraCardViewController = soraCardViewController else {
            return
        }

        addChild(soraCardViewController)

        guard let view = soraCardViewController.view else {
            return
        }

        rootView.addChild(soraCardView: view)
        soraCardViewController.didMove(toParent: self)
    }

    override func loadView() {
        view = ChainAssetListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configureTableView()
        configureEmptyView()
        setupEmbededSoraCardView()
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
        rootView.tableView.registerClassForCell(ChainAccountBalanceTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        if #available(iOS 15.0, *) {
            rootView.tableView.sectionHeaderTopPadding = 0
        }
    }

    func configureEmptyView() {
        let viewModel = EmptyViewModel(
            title: R.string.localizable.emptyViewTitle(preferredLanguages: locale.rLanguages),
            description: R.string.localizable.emptyViewDescription(preferredLanguages: locale.rLanguages)
        )
        rootView.bind(emptyViewModel: viewModel)
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
}

// MARK: - ChainAssetListViewInput

extension ChainAssetListViewController: ChainAssetListViewInput {
    func didReceive(viewModel: ChainAssetListViewModel) {
        let isInitialReload = self.viewModel == nil

        self.viewModel = viewModel
        rootView.apply(state: .normal)
        hiddenSectionState = viewModel.hiddenSectionState

        if isInitialReload {
            rootView.tableView.reloadData()
        } else {
            let debounce = debounce(delay: DispatchTimeInterval.milliseconds(250)) { [weak self] in
                self?.rootView.tableView.reloadData()
            }
            debounce()
        }
    }

    func showEmptyState() {
        rootView.apply(state: .empty)
    }

    func didReceive(soraCardHiddenState: Bool) {
        rootView.changeSoraCardHiddenState(soraCardHiddenState)
    }
}

// MARK: - Localizable

extension ChainAssetListViewController: Localizable {
    func applyLocalization() {
        configureEmptyView()
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
           let assetCell = cell as? ChainAccountBalanceTableCell {
            assetCell.bind(to: cells[indexPath.row])
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
        cell.issueDelegate = self
        return cell
    }
}

extension ChainAssetListViewController: ChainAccountBalanceTableCellDelegate {
    func issueButtonTapped(with indexPath: IndexPath?) {
        guard
            let indexPath = indexPath,
            let viewModel = cellViewModel(for: indexPath)
        else {
            return
        }

        output.didTapOnIssueButton(viewModel: viewModel)
    }
}
