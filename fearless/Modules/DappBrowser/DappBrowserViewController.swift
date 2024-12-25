import UIKit
import SoraUI
import SoraFoundation

protocol DappBrowserViewOutput: AnyObject {
    func didLoad(view: DappBrowserViewInput)
    func didSelect(dapp: TonDapp)
    func didTapOnWalletSelectButton()
    func didTapOnNetworkSelectButton()
    func didTapOnSection(with dapps: [TonDapp], title: String)
    func didTapSearchButton()
    func didSelect(page: DappBrowserViewControllerPage)
}

final class DappBrowserViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = DappBrowserViewLayout

    // MARK: Private properties

    private let output: DappBrowserViewOutput

    private var viewModel: [DappBrowserViewModel] = []

    // MARK: - Constructor

    init(
        output: DappBrowserViewOutput,
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
        view = DappBrowserViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupTableView()
        bindActions()
        rootView.segmentedControl.delegate = self
    }

    // MARK: - Private methods

    private func setupTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(DappBrowserListCell.self)
        rootView.tableView.separatorStyle = .none
    }

    private func bindActions() {
        rootView.featuredView.didSelectApp = { [weak self] index in
            guard
                case let .featured(models) = self?.viewModel[safe: 0],
                let dapp = models[safe: index]?.dapp
            else {
                return
            }
            self?.output.didSelect(dapp: dapp)
        }
        rootView.switchWalletButton.addAction { [weak self] in
            self?.output.didTapOnWalletSelectButton()
        }
        rootView.selectNetworkButton.addAction { [weak self] in
            self?.output.didTapOnNetworkSelectButton()
        }
        rootView.searchButton.addAction { [weak self] in
            self?.output.didTapSearchButton()
        }
    }

    private func didTapOnSeeAll(for section: Int) {
        guard
            let section = viewModel[safe: section],
            case let .section(sectionViewModel) = section
        else {
            return
        }
        output.didTapOnSection(with: sectionViewModel.dapps, title: sectionViewModel.header.title)
    }
}

// MARK: - DappBrowserViewInput

extension DappBrowserViewController: DappBrowserViewInput {
    func didReceive(viewModel: [DappBrowserViewModel]) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()
        if let dataSource = viewModel.first(where: { $0.featured != nil })?.featured {
            rootView.featuredView.set(dataSource: dataSource)
        }
        let sections = IndexSet(integersIn: 0 ..< viewModel.count)
        if sections.isNotEmpty {
            let page = DappBrowserViewControllerPage(rawValue: rootView.segmentedControl.selectedSegmentIndex)
            switch page {
            case .dapps:
                rootView.tableView.reloadSections(sections, with: .left)
            case .connected:
                rootView.tableView.reloadSections(sections, with: .right)
            case nil:
                rootView.tableView.reloadData()
            }
        }
        reloadEmptyState(animated: true)
    }

    func didReceive(walletName: String) {
        rootView.walletNameTitle.text = walletName
    }

    func didReceive(viewModel: DappBrowsetNetworkFilterViewModel?) {
        rootView.selectNetworkButton.applySelectableStyle(false)
        rootView.selectNetworkButton.isHidden = viewModel == nil
        guard let viewModel else {
            return
        }
        rootView.selectNetworkButton.set(
            text: viewModel.networkName,
            image: viewModel.image
        )
    }
}

// MARK: - Localizable

extension DappBrowserViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UITableViewDataSource

extension DappBrowserViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModel[section] {
        case .featured:
            return 1
        case let .section(sectionList):
            return sectionList.list.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel[indexPath.section] {
        case .featured:
            let cell = UITableViewCell()
            cell.contentView.addSubview(rootView.featuredView)
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            rootView.featuredView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview()
            }
            return cell
        case let .section(sectionList):
            let cell = tableView.dequeueReusableCellWithType(DappBrowserListCell.self, forIndexPath: indexPath)

            var position: DappBrowserListCell.Position = .middle
            if indexPath.row == 0, tableView.numberOfRows(inSection: indexPath.section) > 1 {
                position = .top
            } else if indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1 {
                position = .bottom
            }
            let viewModel = sectionList.list[indexPath.row]
            cell.configure(model: viewModel, position: position)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension DappBrowserViewController: UITableViewDelegate {
    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModel[section] {
        case .featured:
            return nil
        case let .section(sectionList):
            let view = DappBrowserSectionHeaderView()
            view.allTapAction = { [weak self] in
                self?.didTapOnSeeAll(for: section)
            }
            view.locale = selectedLocale
            let viewModel = sectionList.header
            view.configure(model: viewModel)
            return view
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch viewModel[section] {
        case .featured:
            return 0
        case .section:
            return 42
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch viewModel[indexPath.section] {
        case .featured:
            return UIScreen.width / 3.4
        case .section:
            return 64
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard
            let section = viewModel[safe: indexPath.section],
            case let .section(sectionListViewModel) = section,
            let dapp = sectionListViewModel.dapps[safe: indexPath.row]
        else {
            return
        }
        output.didSelect(dapp: dapp)
    }
}

// MARK: - FWSegmentedControlDelegate

enum DappBrowserViewControllerPage: Int {
    case dapps
    case connected
}

extension DappBrowserViewController: FWSegmentedControlDelegate {
    func didSelect(_ segmentIndex: Int) {
        guard let page = DappBrowserViewControllerPage(rawValue: segmentIndex) else {
            return
        }
        output.didSelect(page: page)
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension DappBrowserViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension DappBrowserViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarning()
        emptyView.title = R.string.localizable.emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        let page = DappBrowserViewControllerPage(rawValue: rootView.segmentedControl.selectedSegmentIndex)
        switch page {
        case .dapps:
            emptyView.text = R.string.localizable.dappNotFoundTitle(preferredLanguages: selectedLocale.rLanguages)
        case .connected:
            emptyView.text = R.string.localizable.dappNoConnectedDappsTitle(preferredLanguages: selectedLocale.rLanguages)
        case nil:
            break
        }
        emptyView.iconMode = .bigFilledShadow
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.tableContainer
    }
}

// MARK: - EmptyStateDelegate

extension DappBrowserViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        viewModel.compactMap { $0.section }.first == nil
    }
}
