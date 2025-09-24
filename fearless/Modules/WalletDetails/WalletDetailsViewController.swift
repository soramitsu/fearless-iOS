import UIKit
import SoraUI
import SoraFoundation
import SnapKit

final class WalletDetailsViewController: UIViewController, ViewHolder {
    enum Constants {
        static let cellHeight: CGFloat = 72
    }

    typealias RootViewType = WalletDetailsViewLayout

    let output: WalletDetailsViewOutputProtocol
    private var chainViewModels: [WalletDetailsCellViewModel]?
    var keyboardHandler: FearlessKeyboardHandler?

    private var state: WalletDetailsViewState?

    init(output: WalletDetailsViewOutputProtocol) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        bindSearchTextView()
        output.didLoad(ui: self)
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

    @objc private func closeButtonClicked() {
        output.didTapCloseButton()
    }

    @objc private func exportButtonClicked() {
        output.didTapExportButton()
    }

    private func applyState() {
        guard let state = state else {
            return
        }

        switch state {
        case let .normal(viewModel):
            rootView.tableView.reloadData()
            rootView.bind(to: viewModel)
        case let .export(viewModel):
            rootView.bind(to: viewModel)
            rootView.tableView.reloadData()
        }
    }

    private func bindSearchTextView() {
        rootView.searchTextField.onTextDidChanged = { [weak self] text in
            self?.output.searchTextDidChanged(text)
        }
    }
}

extension WalletDetailsViewController: WalletDetailsViewProtocol {
    func didReceive(state: WalletDetailsViewState) {
        self.state = state
        applyState()
        reloadEmptyState(animated: true)
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
    }
}

private extension WalletDetailsViewController {
    func configure() {
        rootView.tableView.registerClassForCell(WalletDetailsTableCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: WalletDetailsTableHeaderView.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(closeButtonClicked),
            for: .touchUpInside
        )

        rootView.exportButton.addTarget(
            self,
            action: #selector(exportButtonClicked),
            for: .touchUpInside
        )
    }
}

extension WalletDetailsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        switch state {
        case let .normal(viewModel):
            return viewModel.sections.count
        case let .export(viewModel):
            return viewModel.sections.count
        case .none:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view: WalletDetailsTableHeaderView = tableView.dequeueReusableHeaderFooterView()
        switch state {
        case let .normal(viewModel):
            let title = viewModel.sections[section].title
            view.setTitle(text: title)
            return view
        case let .export(viewModel):
            let title = viewModel.sections[section].title
            view.setTitle(text: title)
            return view
        case .none:
            return nil
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch state {
        case let .normal(viewModel):
            return viewModel.sections[section].viewModels.count
        case let .export(viewModel):
            return viewModel.sections[section].viewModels.count
        case .none:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(WalletDetailsTableCell.self) else {
            return UITableViewCell()
        }

        switch state {
        case let .normal(viewModel):
            let cellModel = viewModel.sections[indexPath.section].viewModels[indexPath.row]
            cell.bind(to: cellModel)
            cell.delegate = self
            return cell
        case let .export(viewModel):
            let cellModel = viewModel.sections[indexPath.section].viewModels[indexPath.row]
            cell.bind(to: cellModel)
            cell.delegate = self
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        Constants.cellHeight
    }
}

extension WalletDetailsViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch state {
        case let .normal(viewModel):
            UIPasteboard.general.string = viewModel.sections[indexPath.section].viewModels[indexPath.row].address
        case let .export(viewModel):
            UIPasteboard.general.string = viewModel.sections[indexPath.section].viewModels[indexPath.row].address
        case .none:
            break
        }

        if let chain = chainViewModels?[indexPath.row], let address = chain.address {
            UIPasteboard.general.string = address
        }
    }
}

extension WalletDetailsViewController: WalletDetailsTableCellDelegate {
    func didTapActions(_ cell: WalletDetailsTableCell) {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return
        }

        switch state {
        case let .normal(viewModel):
            let cellModel = viewModel.sections[indexPath.section].viewModels[indexPath.row]
            output.showActions(for: cellModel.chain, account: cellModel.account)
        default:
            break
        }
    }
}

extension WalletDetailsViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { 0 }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - EmptyStateViewOwnerProtocol

extension WalletDetailsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension WalletDetailsViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarningGray()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: rootView.locale?.rLanguages)
        emptyView.text = R.string.localizable.emptyViewDescription(preferredLanguages: rootView.locale?.rLanguages)
        emptyView.iconMode = .smallFilled
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.container
    }
}

// MARK: - EmptyStateDelegate

extension WalletDetailsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        switch state {
        case let .normal(viewModel):
            return viewModel.sections.isEmpty
        case let .export(viewModel):
            return viewModel.sections.isEmpty
        case .none:
            return false
        }
    }
}
