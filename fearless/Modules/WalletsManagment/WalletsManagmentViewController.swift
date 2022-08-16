import UIKit
import SoraFoundation

final class WalletsManagmentViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletsManagmentViewLayout

    // MARK: Private properties

    private let output: WalletsManagmentViewOutput
    private var viewModels: [WalletsManagmentCellViewModel] = [] {
        didSet {
            rootView.tableView.reloadData()
        }
    }

    // MARK: - Constructor

    init(
        output: WalletsManagmentViewOutput,
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
        view = WalletsManagmentViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        configure()
        output.didLoad(view: self)
    }

    // MARK: - Private methods

    private func configureTableView() {
        rootView.tableView.backgroundColor = R.color.colorBlack()!
        rootView.tableView.separatorStyle = .none
        rootView.tableView.registerClassForCell(WalletsManagmentTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }

    private func configure() {
        rootView.addNewWalletButton.addTarget(self, action: #selector(addNewWalletTapped), for: .touchUpInside)
        rootView.importWalletButton.addTarget(self, action: #selector(importWalletTapped), for: .touchUpInside)
        rootView.backButton.addTarget(self, action: #selector(closeDidTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func addNewWalletTapped() {
        output.didTapNewWallet()
    }

    @objc private func importWalletTapped() {
        output.didTapImportWallet()
    }

    @objc private func closeDidTapped() {
        output.didTapClose()
    }
}

// MARK: - WalletsManagmentViewInput

extension WalletsManagmentViewController: WalletsManagmentViewInput {
    func didReceiveViewModels(_ viewModels: [WalletsManagmentCellViewModel]) {
        self.viewModels = viewModels
    }
}

// MARK: - Localizable

extension WalletsManagmentViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UITableViewDataSource

extension WalletsManagmentViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(WalletsManagmentTableCell.self) else {
            return UITableViewCell()
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension WalletsManagmentViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? WalletsManagmentTableCell else {
            return
        }

        cell.bind(to: viewModels[indexPath.row])
        cell.delegate = self
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        output.didTap(on: indexPath)
    }
}

// MARK: - WalletsManagmentTableCellDelegate

extension WalletsManagmentViewController: WalletsManagmentTableCellDelegate {
    func didTapOptionsCell(with indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            return
        }
        output.didTapOptions(for: indexPath)
    }
}
