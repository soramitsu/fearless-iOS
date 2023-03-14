import UIKit
import SoraFoundation

final class SelectExportAccountViewController: UIViewController, ViewHolder {
    typealias RootViewType = SelectExportAccountViewLayout

    // MARK: Private properties

    private let output: SelectExportAccountViewOutput

    private var state: SelectExportAccountViewState? {
        didSet {
            applyState()
        }
    }

    // MARK: - Constructor

    init(
        output: SelectExportAccountViewOutput,
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
        view = SelectExportAccountViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configureTableView()
        configure()
    }

    // MARK: - Private methods

    private func configureTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.separatorStyle = .none
        rootView.tableView.registerClassForCell(SelectableExportAccountTableCell.self)
    }

    private func configure() {
        rootView.continueButton.addTarget(self, action: #selector(continueDidTap), for: .touchUpInside)
    }

    private func applyState() {
        guard let state = state else {
            return
        }

        switch state {
        case let .loading(viewModel):
            rootView.configureProfileInfo(
                title: viewModel.metaAccountName,
                subtitle: viewModel.metaAccountBalance
            )
        case .loaded:
            rootView.tableView.reloadData()
        }
    }

    @objc private func continueDidTap() {
        guard case .loaded = state else { return }
        output.exportNativeAccounts()
    }

    private func viewModelWasSelected() -> Bool {
        guard case let .loaded(viewModel) = state else { return false }

        let addedAccountsWasSelected = viewModel.addedAccountsCellViewModels?.first(where: {
            $0.isSelected == true
        }).map(\.isSelected)
        return (addedAccountsWasSelected ?? viewModel.nativeAccountCellViewModel?.isSelected) ?? false
    }
}

extension SelectExportAccountViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        return (viewModel.nativeAccountCellViewModel != nil).intValue
            + (viewModel.addedAccountsCellViewModels != nil).intValue
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        if section == 0 {
            return (viewModel.nativeAccountCellViewModel != nil).intValue
        }

        return viewModel.addedAccountsCellViewModels?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state,
              let cell = tableView.dequeueReusableCellWithType(SelectableExportAccountTableCell.self) else {
            return UITableViewCell()
        }

        if let cellModel: SelectExportAccountCellViewModel = (
            indexPath.section == 0
                ? viewModel.nativeAccountCellViewModel
                : viewModel.addedAccountsCellViewModels?[indexPath.row]
        ) {
            cell.bind(viewModel: cellModel)
        }

        return cell
    }
}

extension SelectExportAccountViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            output.exportNativeAccounts()
        }
    }
}

// MARK: - SelectExportAccountViewInput

extension SelectExportAccountViewController: SelectExportAccountViewInput {
    func didReceive(state: SelectExportAccountViewState) {
        self.state = state
        applyState()
    }
}

// MARK: - Localizable

extension SelectExportAccountViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
