import UIKit
import SoraFoundation
import SoraUI

final class YourValidatorListViewController: UIViewController, ViewHolder {
    private enum Constants {
        static let warningHeaderMargins = UIEdgeInsets(
            top: 0.0,
            left: 0.0,
            bottom: 8.0,
            right: 0.0
        )

        static let regularHeaderMargins = UIEdgeInsets(
            top: 16.0,
            left: 0.0,
            bottom: 8.0,
            right: 0.0
        )

        static let notTopStatusHeaderMargins = UIEdgeInsets(
            top: 32.0,
            left: 0.0,
            bottom: 8.0,
            right: 0.0
        )
    }

    typealias RootViewType = YourValidatorListViewLayout

    var presenter: YourValidatorListPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private var viewState: YourValidatorListViewState?

    let counterFormater: LocalizableResource<NumberFormatter>

    init(
        presenter: YourValidatorListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        counterFormater: LocalizableResource<NumberFormatter> = NumberFormatter.quantity.localizableResource()
    ) {
        self.presenter = presenter
        self.counterFormater = counterFormater

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle -

    override func loadView() {
        view = YourValidatorListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupTableView()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingYourValidatorsTitle(preferredLanguages: selectedLocale.rLanguages)

        navigationItem.rightBarButtonItem?.title = R.string.localizable
            .commonChange(preferredLanguages: selectedLocale.rLanguages)
    }

    private func setupNavigationItem() {
        let resetItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(actionChange)
        )

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!,
            .font: UIFont.p0Paragraph
        ]

        let highlightedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!.withAlphaComponent(0.5),
            .font: UIFont.p0Paragraph
        ]

        resetItem.setTitleTextAttributes(normalAttributes, for: .normal)
        resetItem.setTitleTextAttributes(highlightedAttributes, for: .highlighted)

        navigationItem.rightBarButtonItem = resetItem
    }

    private func setupTableView() {
        rootView.tableView.registerClassesForCell([
            YourValidatorTableCell.self
        ])

        rootView.tableView.registerHeaderFooterView(
            withClass: YourValidatorListDescSectionView.self
        )

        rootView.tableView.registerHeaderFooterView(
            withClass: YourValidatorListStatusSectionView.self
        )

        rootView.tableView.registerHeaderFooterView(
            withClass: YourValidatorListWarningSectionView.self
        )

        rootView.tableView.rowHeight = 48

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    @objc func actionChange() {
        presenter.changeValidators()
    }
}

// MARK: - UITableViewDataSource

extension YourValidatorListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard let sections = viewState?.validatorListViewModel?.sections else {
            return 0
        }

        return sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = viewState?.validatorListViewModel?.sections else {
            return 0
        }

        return sections[section].validators.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(YourValidatorTableCell.self)!

        let section = viewState?.validatorListViewModel?.sections[indexPath.section]
        let validator = section!.validators[indexPath.row]

        cell.bind(viewModel: validator, for: selectedLocale)

        return cell
    }
}

// MARK: UITableViewDelegate

extension YourValidatorListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = viewState?.validatorListViewModel?.sections[indexPath.section] else {
            return
        }

        presenter.didSelectValidator(viewModel: section.validators[indexPath.row])
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let viewModel = viewState?.validatorListViewModel else {
            return nil
        }

        let sectionViewModel = viewModel.sections[section]

        switch sectionViewModel.status {
        case .stakeAllocated:
            let count = viewModel.sections.first(where: { $0.status == .stakeNotAllocated }).map {
                $0.validators.count + sectionViewModel.validators.count
            } ?? sectionViewModel.validators.count

            if viewModel.hasValidatorWithoutRewards {
                let headerView: YourValidatorListWarningSectionView = tableView.dequeueReusableHeaderFooterView()
                configureWarning(headerView: headerView, validatorsCount: count)
                return headerView
            } else {
                let headerView: YourValidatorListStatusSectionView = tableView.dequeueReusableHeaderFooterView()
                configureElected(headerView: headerView, validatorsCount: count)
                return headerView
            }
        case .stakeNotAllocated:
            let headerView: YourValidatorListDescSectionView = tableView.dequeueReusableHeaderFooterView()
            configureNotAllocated(headerView: headerView)

            if section > 0 {
                headerView.borderView.borderType = .top
            } else {
                headerView.borderView.borderType = .none
            }

            headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins

            return headerView
        case .unelected:
            let headerView: YourValidatorListStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            configureUnelected(
                headerView: headerView,
                validatorsCount: sectionViewModel.validators.count,
                section: section
            )

            return headerView
        case .pending:
            let headerView: YourValidatorListStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            configurePending(
                headerView: headerView,
                validatorsCount: sectionViewModel.validators.count,
                section: section
            )

            return headerView
        }
    }

    private func configureWarning(headerView: YourValidatorListWarningSectionView, validatorsCount: Int) {
        configureElected(headerView: headerView, validatorsCount: validatorsCount)

        let text = R.string.localizable.stakingYourOversubscribedMessage(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.bind(warningText: text)

        headerView.borderView.borderType = .none
        headerView.mainStackView.layoutMargins = Constants.warningHeaderMargins
    }

    private func configureElected(headerView: YourValidatorListStatusSectionView, validatorsCount: Int) {
        let icon = R.image.iconAlgoItem()!
        let title = counterFormater.value(for: selectedLocale).string(from: NSNumber(value: validatorsCount)).map {
            R.string.localizable.stakingYourElectedFormat($0)
        } ?? ""

        let value = R.string.localizable.stakingCommonRewardsApy(preferredLanguages: selectedLocale.rLanguages)

        let description = R.string.localizable.stakingYourAllocatedDescription(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.statusView.titleLabel.textColor = R.color.colorWhite()

        headerView.bind(icon: icon, title: title, value: value)
        headerView.bind(description: description)

        headerView.borderView.borderType = .none
        headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
    }

    private func configureNotAllocated(headerView: YourValidatorListDescSectionView) {
        let description = R.string.localizable.stakingYourNotAllocatedDescription(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.bind(description: description)
    }

    private func configureUnelected(
        headerView: YourValidatorListStatusSectionView,
        validatorsCount: Int,
        section: Int
    ) {
        let icon = R.image.iconLightPending()!
        let title = counterFormater.value(for: selectedLocale).string(from: NSNumber(value: validatorsCount)).map {
            R.string.localizable.stakingYourNotElectedFormat($0)
        } ?? ""

        let description = R.string.localizable.stakingYourInactiveDescription(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.statusView.titleLabel.textColor = R.color.colorLightGray()

        headerView.bind(icon: icon, title: title, value: "")
        headerView.bind(description: description)

        if section > 0 {
            headerView.borderView.borderType = .top
            headerView.mainStackView.layoutMargins = Constants.notTopStatusHeaderMargins
        } else {
            headerView.borderView.borderType = .none
            headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
        }
    }

    private func configurePending(
        headerView: YourValidatorListStatusSectionView,
        validatorsCount: Int,
        section: Int
    ) {
        let icon = R.image.iconLightPending()!
        let title = counterFormater.value(for: selectedLocale).string(from: NSNumber(value: validatorsCount)).map {
            R.string.localizable.stakingYourSelectedFormat($0)
        } ?? ""

        let description = R.string.localizable.stakingYourValidatorsChangingTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.statusView.titleLabel.textColor = R.color.colorLightGray()

        headerView.bind(icon: icon, title: title, value: "")
        headerView.bind(description: description)

        if section > 0 {
            headerView.borderView.borderType = .top
            headerView.mainStackView.layoutMargins = Constants.notTopStatusHeaderMargins
        } else {
            headerView.borderView.borderType = .none
            headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
        }
    }
}

extension YourValidatorListViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.retry()
    }
}

extension YourValidatorListViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension YourValidatorListViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let state = viewState else { return nil }

        switch state {
        case let .error(error):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = error.value(for: selectedLocale)
            errorView.delegate = self
            return errorView
        case .loading, .validatorList:
            return nil
        }
    }
}

extension YourValidatorListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let state = viewState else { return false }
        switch state {
        case .error:
            return true
        case .loading, .validatorList:
            return false
        }
    }
}

extension YourValidatorListViewController: YourValidatorListViewProtocol {
    func reload(state: YourValidatorListViewState) {
        viewState = state

        if case .loading = viewState {
            didStartLoading()
        } else {
            didStopLoading()
        }

        rootView.tableView.reloadData()
        reloadEmptyState(animated: true)
    }
}

extension YourValidatorListViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
        }
    }
}
