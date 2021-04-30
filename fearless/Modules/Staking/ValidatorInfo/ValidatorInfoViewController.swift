import UIKit
import SoraFoundation

final class ValidatorInfoViewController: UIViewController {
    var viewModel: [ValidatorInfoViewModel] = []

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
        tableView.register(
            UINib(resource: R.nib.validatorInfoAccountCell),
            forCellReuseIdentifier: R.reuseIdentifier.validatorAccountCellId.identifier
        )

        tableView.register(
            UINib(resource: R.nib.validatorInfoGenericCell),
            forCellReuseIdentifier: R.reuseIdentifier.validatorInfoGenericCellId.identifier
        )

        tableView.registerClassForCell(ValidatorInfoEmptyStakeCell.self)

        tableView.alwaysBounceVertical = false
    }
}

extension ValidatorInfoViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch viewModel[section] {
        case .account:
            return CGFloat.leastNormalMagnitude
        default:
            return ValidatorInfoViewModel.headerHeight
        }
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch viewModel[indexPath.section] {
        case .account:
            return ValidatorInfoViewModel.accountRowHeight
        case .emptyStake:
            return ValidatorInfoViewModel.emptyStakeRowHeight
        default:
            return ValidatorInfoViewModel.rowHeight
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch viewModel[indexPath.section] {
        case .account: presenter.presentAccountOptions()

        case let .myNomination(rows):
            switch rows[indexPath.row] {
            case let .status(_, state): presenter.presentStateDescription(for: state)
            default: break
            }

        case let .staking(rows):
            switch rows[indexPath.row] {
            case .totalStake: presenter.presentTotalStake()
            default: break
            }

        case let .identity(rows):
            switch rows[indexPath.row] {
            case .email: presenter.activateEmail()
            case .web: presenter.activateWeb()
            case .twitter: presenter.activateTwitter()
            case .riot: presenter.activateRiotName()
            default: break
            }

        default: break
        }
    }
}

extension ValidatorInfoViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModel[section] {
        case .account, .emptyStake: return 1
        case let .myNomination(rows): return rows.count
        case let .staking(rows): return rows.count
        case let .identity(rows): return rows.count
        }
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let view = UINib(resource: R.nib.validatorInfoHeaderView)
            .instantiate(withOwner: nil, options: nil).first as? ValidatorInfoHeaderView
        else {
            return nil
        }

        switch viewModel[section] {
        case .myNomination:
            view.bind(title: R.string.localizable.stakingYourNominationTitle(preferredLanguages: locale?.rLanguages))
        case .staking, .emptyStake:
            view.bind(title: R.string.localizable.stakingTitle(preferredLanguages: locale?.rLanguages))
        case .identity:
            view.bind(title: R.string.localizable.identityTitle(preferredLanguages: locale?.rLanguages))
        default:
            return nil
        }

        return view
    }

    // swiftlint:disable:next cyclomatic_complexity
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        func informationCell(
            with model: LocalizableResource<TitleWithSubtitleViewModel>,
            selectionStyle: UITableViewCell.SelectionStyle = .default
        ) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorInfoGenericCellId,
                for: indexPath
            )!
            cell.setStyle(.info)
            cell.bind(model: model.value(for: locale))
            cell.selectionStyle = selectionStyle
            return cell
        }

        func statusCell(
            with model: LocalizableResource<TitleWithSubtitleViewModel>,
            state: ValidatorMyNominationStatus
        ) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorInfoGenericCellId,
                for: indexPath
            )!
            cell.setStyle(.info)
            cell.bind(model: model.value(for: locale), state: state)
            return cell
        }

        func amountCell(
            with model: LocalizableResource<StakingAmountViewModel>
        ) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorInfoGenericCellId,
                for: indexPath
            )!
            cell.setStyle(.totalStake)
            cell.bind(model: model.value(for: locale))
            return cell
        }

        func balanceCell(
            with model: LocalizableResource<StakingAmountViewModel>
        ) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorInfoGenericCellId,
                for: indexPath
            )!
            cell.setStyle(.balance)
            cell.bind(model: model.value(for: locale))
            cell.selectionStyle = .none
            return cell
        }

        func titleSubtitleCell(
            with model: LocalizableResource<TitleWithSubtitleViewModel>,
            selectionStyle: UITableViewCell.SelectionStyle = .default
        )
            -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorInfoGenericCellId,
                for: indexPath
            )!
            cell.bind(model: model.value(for: locale))
            cell.selectionStyle = selectionStyle
            return cell
        }

        func nominatorsCell(
            with model: LocalizableResource<TitleWithSubtitleViewModel>,
            oversubscribed: Bool,
            selectionStyle _: UITableViewCell.SelectionStyle = .default
        ) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorInfoGenericCellId,
                for: indexPath
            )!
            cell.bind(model: model.value(for: locale))
            cell.selectionStyle = oversubscribed ? .default : .none
            if oversubscribed { cell.setStyle(.oversubscribed) }
            return cell
        }

        func webCell(with model: LocalizableResource<TitleWithSubtitleViewModel>) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorInfoGenericCellId,
                for: indexPath
            )!
            cell.setStyle(.web)
            cell.bind(model: model.value(for: locale))
            return cell
        }

        let locale = self.locale ?? Locale.current

        switch viewModel[indexPath.section] {
        case let .account(model):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.validatorAccountCellId,
                for: indexPath
            )!
            cell.bind(model: model)
            return cell

        case let .myNomination(rows):
            switch rows[indexPath.row] {
            case let .status(model, state): return statusCell(with: model, state: state)
            case let .nominatedAmount(model): return balanceCell(with: model)
            }

        case let .emptyStake(model):
            let cell = tableView.dequeueReusableCellWithType(ValidatorInfoEmptyStakeCell.self)!
            cell.bind(model: model.value(for: locale))
            return cell

        case let .staking(rows):
            switch rows[indexPath.row] {
            case let .totalStake(model): return informationCell(with: model)
            case let .nominators(model, oversubscribed): return nominatorsCell(with: model, oversubscribed: oversubscribed)
            case let .estimatedReward(model): return titleSubtitleCell(with: model, selectionStyle: .none)
            }

        case let .identity(rows):
            switch rows[indexPath.row] {
            case let .legalName(model): return titleSubtitleCell(with: model, selectionStyle: .none)
            case let .email(model): return webCell(with: model)
            case let .riot(model): return webCell(with: model)
            case let .twitter(model): return webCell(with: model)
            case let .web(model): return webCell(with: model)
            }
        }
    }
}

// MARK: - ValidatorInfoViewProtocol

extension ValidatorInfoViewController: ValidatorInfoViewProtocol {
    func didRecieve(_ viewModel: [ValidatorInfoViewModel]) {
        self.viewModel = viewModel
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
