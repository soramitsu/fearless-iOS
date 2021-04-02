import UIKit
import SoraFoundation

final class ValidatorInfoViewController: UIViewController {
    typealias Row = (rowType: RowType, content: LocalizableResource<TitleWithSubtitleViewModel>)
    typealias Section = (sectionType: SectionType, rows: [Row])

    enum RowType: Int {
        static let accountRowHeight: CGFloat = 56.0
        static let rowHeight: CGFloat = 48.0

        case totalStake
        case nominators
        case estimatedReward
        case legalName
        case email
        case web
        case twitter
        case riot
    }

    enum SectionType: Int, CaseIterable {
        static let rowHeight: CGFloat = 52.0

        case staking
        case identity
    }

    var accountViewModel: ValidatorInfoAccountViewModelProtocol?
    var extrasViewModel: [Section] = []

    @IBOutlet var tableView: UITableView!

    var presenter: ValidatorInfoPresenterProtocol!
    var locale: Locale?

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        setupLocalization()
        presenter.setup()
    }

    private func configureTableView() {
        // Cell for validator account display
        tableView.register(
            UINib(resource: R.nib.validatorInfoAccountCell),
            forCellReuseIdentifier: R.reuseIdentifier.validatorAccountCellId.identifier
        )

        tableView.register(
            UINib(resource: R.nib.validatorInfoInformationCell),
            forCellReuseIdentifier: R.reuseIdentifier.validatorInfoInformationCellId.identifier
        )

        tableView.register(
            UINib(resource: R.nib.validatorInfoTitleSubtitleCell),
            forCellReuseIdentifier: R.reuseIdentifier.validatorInfoTitleSubtitleCellId.identifier
        )

        tableView.register(
            UINib(resource: R.nib.validatorInfoWebCell),
            forCellReuseIdentifier: R.reuseIdentifier.validatorInfoWebCellId.identifier
        )

        tableView.alwaysBounceVertical = false
    }
}

extension ValidatorInfoViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.section > 0 else { return RowType.accountRowHeight }

        return RowType.rowHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section > 0 else {
            presenter.presentAccountOptions()
            return
        }

        switch extrasViewModel[indexPath.section - 1].rows[indexPath.row].rowType {
        case .totalStake:
            presenter.presentTotalStake()
        case .email:
            presenter.activateEmail()
        case .web:
            presenter.activateWeb()
        case .twitter:
            presenter.activateTwitter()
        case .riot:
            presenter.activateRiotName()
        case .estimatedReward, .legalName, .nominators:
            break
        }
    }
}

extension ValidatorInfoViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1 + extrasViewModel.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        default:
            return extrasViewModel[section - 1].rows.count
        }
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let view = UINib(resource: R.nib.validatorInfoHeaderView)
            .instantiate(withOwner: nil, options: nil).first as? ValidatorInfoHeaderView
        else {
            return nil
        }

        switch extrasViewModel[section - 1].sectionType {
        case .staking:
            view.bind(title: R.string.localizable.stakingTitle(preferredLanguages: locale?.rLanguages))
        case .identity:
            view.bind(title: R.string.localizable.identityTitle(preferredLanguages: locale?.rLanguages))
        }

        return view
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section > 0 else { return 0.0 }
        return SectionType.rowHeight
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section > 0 else {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorAccountCellId,
                for: indexPath
            )!

            if let accountViewModel = accountViewModel {
                cell.bind(model: accountViewModel)
            }

            return cell
        }

        let locale = self.locale ?? Locale.current

        let row = extrasViewModel[indexPath.section - 1].rows[indexPath.row]
        let rowType = row.rowType

        switch rowType {
        case .totalStake:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorInfoInformationCellId,
                for: indexPath
            )!

            cell.bind(model: row.content.value(for: locale))

            return cell

        case .nominators, .estimatedReward, .legalName:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorInfoTitleSubtitleCellId,
                for: indexPath
            )!

            cell.selectionStyle = .none

            cell.bind(model: row.content.value(for: locale))

            return cell

        case .email, .web, .twitter, .riot:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorInfoWebCellId,
                for: indexPath
            )!
            cell.bind(model: row.content.value(for: locale))
            return cell
        }
    }
}

// MARK: - ValidatorInfoViewProtocol

extension ValidatorInfoViewController: ValidatorInfoViewProtocol {
    func didReceive(
        accountViewModel: ValidatorInfoAccountViewModelProtocol,
        extrasViewModel: [Section]
    ) {
        self.accountViewModel = accountViewModel
        self.extrasViewModel = extrasViewModel
        tableView.reloadData()
    }
}

// MARK: - Localizable

extension ValidatorInfoViewController: Localizable {
    private func setupLocalization() {
        title = R.string.localizable
            .stakingValidatorInfoTitle(preferredLanguages: locale?.rLanguages)
        tableView.reloadData()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
