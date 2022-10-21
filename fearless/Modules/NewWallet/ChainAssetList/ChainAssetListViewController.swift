import UIKit
import SoraFoundation

final class ChainAssetListViewController: UIViewController, ViewHolder {
    enum HiddenSectionState {
        case hidden
        case expanded
    }

    enum Constants {
        static let sectionHeaderHeight: CGFloat = 80
    }

    typealias RootViewType = ChainAssetListViewLayout

    // MARK: Private properties

    private let output: ChainAssetListViewOutput

    private var viewModel: ChainAssetListViewModel?
    private var hiddenSectionState: HiddenSectionState = .expanded
    private lazy var locale: Locale = {
        localizationManager?.selectedLocale ?? Locale.current
    }()

    // MARK: - Constructor

    init(
        output: ChainAssetListViewOutput,
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
        view = ChainAssetListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configureTableView()
        configureEmptyView()
    }

    // MARK: - Private methods
}

private extension ChainAssetListViewController {
    func configureTableView() {
        rootView.tableView.registerClassForCell(ChainAccountBalanceTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
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
        }
        rootView.tableView.reloadData()
    }
}

// MARK: - ChainAssetListViewInput

extension ChainAssetListViewController: ChainAssetListViewInput {
    func runtimesBuilded(count: Int) {
        rootView.bindRuntimeLabel(count: count)
    }

    func didReceive(viewModel: ChainAssetListViewModel) {
        self.viewModel = viewModel
        rootView.apply(state: .normal)
        rootView.tableView.reloadData()
    }

    func showEmptyState() {
        rootView.apply(state: .empty)
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
            return Constants.sectionHeaderHeight
        }
        return 0
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
        if let sect = viewModel?.sections[indexPath.section],
           let cells = viewModel?.cellsForSections[sect] {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: ChainAccountBalanceTableCell.reuseIdentifier,
                for: indexPath
            ) as? ChainAccountBalanceTableCell else {
                return UITableViewCell()
            }
            cell.bind(to: cells[indexPath.row])
            cell.delegate = self
            cell.issueDelegate = self
            return cell
        }
        return UITableViewCell()
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
