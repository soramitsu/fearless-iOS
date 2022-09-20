import UIKit
import SoraFoundation

final class SelectCurrencyViewController: UIViewController, ViewHolder {
    typealias RootViewType = SelectCurrencyViewLayout

    // MARK: Private properties

    private let isModal: Bool
    private let output: SelectCurrencyViewOutput
    private var viewModels: [SelectCurrencyCellViewModel]?

    // MARK: - Constructor

    init(
        isModal: Bool,
        output: SelectCurrencyViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        self.isModal = isModal
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = SelectCurrencyViewLayout(isModal: isModal)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupActions()
        setupTableView()
        output.didLoad(view: self)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.rightButton.addTarget(self, action: #selector(actionDone), for: .touchUpInside)
        rootView.backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
    }

    private func setupTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.rowHeight = UIConstants.cellHeight
        rootView.tableView.registerClassForCell(SelectCurrencyTableCell.self)
    }

    @objc private func actionDone() {
        guard let selectedViewModel = viewModels?.first(where: { $0.isSelected == true }) else { return }
        output.didSelect(viewModel: selectedViewModel)
    }

    @objc private func back() {
        output.back()
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

        if isModal {
            actionDone()
        } else {
            tableView.reloadData()
        }
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
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
