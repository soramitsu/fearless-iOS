import UIKit
import SoraFoundation

final class ValidatorListFilterViewController: UIViewController, ViewHolder {
    typealias RootViewType = ValidatorListFilterViewLayout

    private enum Constants {
        static let headerId = "validatorListFilterHeaderId"
    }

    let presenter: ValidatorListFilterPresenterProtocol

    private var viewModel: ValidatorListFilterViewModel?

    // MARK: - Lifecycle

    init(
        presenter: ValidatorListFilterPresenterProtocol,
        localizationManager: LocalizationManager
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ValidatorListFilterViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.view = self

        setupResetButton()
        setupApplyButton()
        setupTableView()
        applyLocalization()

        presenter.setup()
    }

    // MARK: - Private functions

    private func setupTableView() {
        rootView.tableView.register(
            UINib(resource: R.nib.iconTitleHeaderView),
            forHeaderFooterViewReuseIdentifier: Constants.headerId
        )
        rootView.tableView.registerClassForCell(TitleSubtitleSwitchTableViewCell.self)
        rootView.tableView.registerClassForCell(ValidatorListFilterSortCell.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.tableView.separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
    }

    private func setupResetButton() {
        let resetButton = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(didTapResetButton)
        )

        resetButton.setupDefaultTitleStyle(with: .p0Paragraph)

        navigationItem.rightBarButtonItem = resetButton
    }

    private func setupApplyButton() {
        rootView.applyButton.addTarget(
            self,
            action: #selector(didTapApplyButton),
            for: .touchUpInside
        )
    }

    private func updateActionButtons() {
        rootView.applyButton.isEnabled = viewModel?.canApply ?? false
        navigationItem.rightBarButtonItem?.isEnabled = viewModel?.canReset ?? false
    }

    // MARK: - Actions

    @objc
    func didTapApplyButton() {
        presenter.applyFilter()
    }

    @objc
    func didTapResetButton() {
        presenter.resetFilter()
    }
}

// MARK: - UITableViewDataSource

extension ValidatorListFilterViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        2
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }

        switch section {
        case 0:
            return viewModel.filterModel.cellViewModels.count
        case 1:
            return viewModel.sortModel.cellViewModels.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else { return UITableViewCell() }

        switch indexPath.section {
        case 0:
            let item = viewModel.filterModel.cellViewModels[indexPath.row]
            let cell = tableView.dequeueReusableCellWithType(TitleSubtitleSwitchTableViewCell.self)!

            cell.bind(viewModel: item)
            cell.delegate = self

            return cell

        case 1:
            let item = viewModel.sortModel.cellViewModels[indexPath.row]
            let cell = tableView.dequeueReusableCellWithType(ValidatorListFilterSortCell.self)!

            cell.bind(viewModel: item)
            return cell

        default:
            return UITableViewCell()
        }
    }
}

// MARK: - UITableViewDelegate

extension ValidatorListFilterViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let view = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: Constants.headerId
        ) as? IconTitleHeaderView else { return nil }

        view.titleView.titleColor = R.color.colorWhite()
        view.titleView?.titleFont = .h4Title
        view.titleView.spacingBetweenLabelAndIcon = 0
        view.titleView.displacementBetweenLabelAndIcon = 0

        let sectionTitle: String = {
            switch section {
            case 0:
                return viewModel?.filterModel.title ?? ""
            case 1:
                return viewModel?.sortModel.title ?? ""
            default:
                return ""
            }
        }()

        view.bind(title: sectionTitle, icon: nil)

        return view
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { return }

        presenter.selectFilterItem(at: indexPath.row)
    }
}

// MARK: - SwitchTableViewCellDelegate

extension ValidatorListFilterViewController: SwitchTableViewCellDelegate {
    func didToggle(cell: SwitchTableViewCell) {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return
        }

        presenter.toggleFilterItem(at: indexPath.row)
    }
}

// MARK: - ValidatorListFilterViewProtocol

extension ValidatorListFilterViewController: ValidatorListFilterViewProtocol {
    func didUpdateViewModel(_ viewModel: ValidatorListFilterViewModel) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()
        updateActionButtons()
    }
}

// MARK: - Localizable

extension ValidatorListFilterViewController: Localizable {
    func applyLocalization() {
        title = R.string.localizable
            .walletFiltersTitle(preferredLanguages: selectedLocale.rLanguages)

        navigationItem.rightBarButtonItem?.title = R.string.localizable
            .commonReset(preferredLanguages: selectedLocale.rLanguages)

        rootView.applyButton.imageWithTitleView?.title = R.string.localizable
            .commonApply(preferredLanguages: selectedLocale.rLanguages)

        rootView.tableView.reloadData()
    }
}
