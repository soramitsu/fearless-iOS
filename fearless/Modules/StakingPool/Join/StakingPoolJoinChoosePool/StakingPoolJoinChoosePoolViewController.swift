import UIKit
import SoraFoundation

final class StakingPoolJoinChoosePoolViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    private enum LayoutConstants {
        static let cellHeight: CGFloat = 77
    }

    typealias RootViewType = StakingPoolJoinChoosePoolViewLayout

    // MARK: Private properties

    private let output: StakingPoolJoinChoosePoolViewOutput
    private var viewModels: [StakingPoolListTableCellModel] = []

    // MARK: - Constructor

    init(
        output: StakingPoolJoinChoosePoolViewOutput,
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
        view = StakingPoolJoinChoosePoolViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        configure()

        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    // MARK: - Private methods

    private func configure() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(StakingPoolListTableCell.self)

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )

        rootView.continueButton.addTarget(
            self,
            action: #selector(continueButtonClicked),
            for: .touchUpInside
        )

        rootView.optionsButton.addTarget(
            self,
            action: #selector(optionsButtonClicked),
            for: .touchUpInside
        )
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func continueButtonClicked() {
        output.didTapContinueButton()
    }

    @objc private func optionsButtonClicked() {
        output.didTapOptionsButton()
    }
}

// MARK: - StakingPoolJoinChoosePoolViewInput

extension StakingPoolJoinChoosePoolViewController: StakingPoolJoinChoosePoolViewInput {
    func didReceive(locale: Locale) {
        rootView.locale = locale
    }

    func didReceive(cellViewModels: [StakingPoolListTableCellModel]) {
        rootView.emptyView.isHidden = cellViewModels.isNotEmpty

        if cellViewModels.first(where: { $0.isSelected == true }) != nil {
            rootView.continueButton.applyEnabledStyle()
        } else {
            rootView.continueButton.applyDisabledStyle()
        }

        viewModels = cellViewModels
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension StakingPoolJoinChoosePoolViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension StakingPoolJoinChoosePoolViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(StakingPoolListTableCell.self) else {
            return UITableViewCell()
        }

        return cell
    }
}

extension StakingPoolJoinChoosePoolViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard
            let cell = cell as? StakingPoolListTableCell
        else {
            return
        }

        cell.bind(to: viewModels[indexPath.row])
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        LayoutConstants.cellHeight
    }
}
