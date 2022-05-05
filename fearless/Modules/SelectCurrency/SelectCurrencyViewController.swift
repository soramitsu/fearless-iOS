import UIKit
import SoraFoundation

final class SelectCurrencyViewController: UIViewController, ViewHolder {
    typealias RootViewType = SelectCurrencyViewLayout

    // MARK: Private properties

    private let output: SelectCurrencyViewOutput
    private var viewModels: [SelectCurrencyCellViewModel]?

    // MARK: - Constructor

    init(
        output: SelectCurrencyViewOutput,
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
        view = SelectCurrencyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupTableView()
        output.didLoad(view: self)
    }

    // MARK: - Private methods

    private func setupNavigationBar() {
        let rightBarButtonItem = UIBarButtonItem(
            title: R.string.localizable.commonDone(preferredLanguages: selectedLocale.rLanguages),
            style: .plain,
            target: self,
            action: #selector(actionDone)
        )
        rightBarButtonItem.setupDefaultTitleStyle(with: .h4Title)
        navigationItem.rightBarButtonItem = rightBarButtonItem
        navigationController?.navigationBar.backgroundColor = R.color.colorBlack()
        title = R.string.localizable.commonCurrency(preferredLanguages: selectedLocale.rLanguages)
    }

    private func setupTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.rowHeight = UIConstants.cellHeight
        rootView.tableView.registerClassForCell(SelectCurrencyTableCell.self)
    }

    @objc func actionDone() {
        guard let selectedViewModel = viewModels?.first(where: { $0.isSelected == true }) else { return }
        output.didSelect(viewModel: selectedViewModel)
    }
}

extension SelectCurrencyViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCellWithType(SelectCurrencyTableCell.self),
            let viewModel = viewModels?[indexPath.row]
        else {
            return UITableViewCell()
        }
        cell.bind(viewModel: viewModel)
        return cell
    }
}

extension SelectCurrencyViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard var viewModels = viewModels else { return }
        for index in 0 ..< viewModels.count {
            viewModels[index].isSelected = false
        }
        viewModels[indexPath.row].isSelected = true
        self.viewModels = viewModels
        tableView.reloadData()
    }
}

// MARK: - SelectCurrencyViewInput

extension SelectCurrencyViewController: SelectCurrencyViewInput {
    func didRecieve(viewModel: [SelectCurrencyCellViewModel]) {
        viewModels = viewModel
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension SelectCurrencyViewController: Localizable {
    func applyLocalization() {}
}
