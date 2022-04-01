import UIKit
import SoraFoundation

final class SelectExportAccountViewController: UIViewController, ViewHolder {
    typealias RootViewType = SelectExportAccountViewLayout

    // MARK: Private properties

    private let output: SelectExportAccountViewOutput

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
    }

    // MARK: - Private methods

    private func configureTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }
}

extension SelectExportAccountViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(SelectableExportAccountTableCell.self) else {
            return UITableViewCell()
        }

        cell.bind(viewModel: ExportAccoutInfo())

        return cell
    }
}

extension SelectExportAccountViewController: UITableViewDelegate {}

// MARK: - SelectExportAccountViewInput

extension SelectExportAccountViewController: SelectExportAccountViewInput {}

// MARK: - Localizable

extension SelectExportAccountViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
