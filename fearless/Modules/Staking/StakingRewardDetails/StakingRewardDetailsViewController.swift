import UIKit
import SoraFoundation

final class StakingRewardDetailsViewController: UIViewController, ViewHolder {

    typealias RootViewType = StakingRewardDetailsViewLayout

    let presenter: StakingRewardDetailsPresenterProtocol

    init(presenter: StakingRewardDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingRewardDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupTable()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.registerClassForCell(StakingRewardDetailsTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }
}

extension StakingRewardDetailsViewController: StakingRewardDetailsViewProtocol {}

extension StakingRewardDetailsViewController: Localizable {

    private func setupLocalization() {
        setupTitleLocalization()
        setupButtonLocalization()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }

    private func setupTitleLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.stakingRewardDetailsTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupButtonLocalization() {
        let title = R.string.localizable.stakingRewardDetailsPayout()
        rootView.payoutButton.imageWithTitleView?.title = title
    }
}

extension StakingRewardDetailsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // TODO FLW-677
    }
}

extension StakingRewardDetailsViewController: UITableViewDataSource {

    // TODO delete stub data
    var stubCellData: [RewardDetailsRow] {
        [.status, .date("3 March 2020"), .era("#1,690"), .reward]
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        stubCellData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = rootView.tableView.dequeueReusableCellWithType(
            StakingRewardDetailsTableCell.self)!
        let model = stubCellData[indexPath.row]
        cell.bind(model: model)
        return cell
    }
}
