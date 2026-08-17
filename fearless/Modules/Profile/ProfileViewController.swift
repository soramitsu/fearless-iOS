import UIKit
import SoraFoundation
import SSFUtils

final class ProfileViewController: UIViewController, ViewHolder {
    typealias RootViewType = ProfileViewLayout

    // MARK: - Constants

    private enum Constants {
        static let optionCellHeight: CGFloat = 48.0
        static let sectionCellHeight: CGFloat = 56.0
        static let detailsCellHeight: CGFloat = 86.0
        static let headerInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 16, right: 16.0)
        static let tableViewFooterHeight: CGFloat = 40.0
    }

    private enum SettingsSection: Int, CaseIterable {
        case profile
        case walletsAccounts
        case networksAssets
        case connections
        case security
        case preferences
        case about
        case logout

        var title: String? {
            switch self {
            case .profile, .logout:
                return nil
            case .walletsAccounts:
                return NSLocalizedString("settings.wallets_accounts", value: "Wallets & Accounts", comment: "")
            case .networksAssets:
                return NSLocalizedString("settings.networks_assets", value: "Networks & Assets", comment: "")
            case .connections:
                return NSLocalizedString("settings.connections", value: "Connections", comment: "")
            case .security:
                return NSLocalizedString("settings.security", value: "Security", comment: "")
            case .preferences:
                return NSLocalizedString("settings.preferences", value: "Preferences", comment: "")
            case .about:
                return NSLocalizedString("settings.about", value: "About", comment: "")
            }
        }

        var options: Set<ProfileOption> {
            switch self {
            case .profile, .logout:
                return []
            case .walletsAccounts:
                return [.accountList]
            case .networksAssets:
                return [.networkAssets]
            case .connections:
                return [.walletConnect, .tonConnect]
            case .security:
                return [.changePincode, .biometry]
            case .preferences:
                return [.currency, .language, .polkaswapDisclaimer, .accountScore]
            case .about:
                return [.about]
            }
        }
    }

    // MARK: - Private properties

    private let presenter: ProfilePresenterProtocol
    private let iconGenerating: IconGenerating

    // MARK: - State

    private var state: ProfileViewState = .loading

    // MARK: - Constructor

    init(
        presenter: ProfilePresenterProtocol,
        iconGenerating: IconGenerating,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        self.iconGenerating = iconGenerating
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        presenter.didLoad(view: self)
    }

    override func loadView() {
        view = ProfileViewLayout()
    }

    // MARK: - Private methods

    private func applyState() {
        switch state {
        case .loading:
            break
        case .loaded:
            rootView.tableView.reloadData()
        }
    }

    @objc func switcherValueChanged(sender: UISwitch) {
        presenter.switcherValueChanged(isOn: sender.isOn, index: sender.tag)
    }

    // MARK: - tableView

    private func prepareProfileSectionCell(
        _ tableView: UITableView,
        indexPath: IndexPath
    ) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(
            withIdentifier: R.reuseIdentifier.profileSectionCellId,
            for: indexPath
        ) {
            let locale = localizationManager?.selectedLocale
            cell.titleLabel.text = R.string.localizable.profileTitle(preferredLanguages: locale?.rLanguages)

            return cell
        } else {
            assertionFailure("Profile section cell creation failed")
            return UITableViewCell()
        }
    }

    private func prepareProfileDetailsCell(
        _ tableView: UITableView,
        with viewModel: WalletsManagmentCellViewModel
    ) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCellWithType(WalletsManagmentTableCell.self) {
            cell.bind(to: viewModel)
            cell.delegate = self
            return cell
        } else {
            assertionFailure("Profile details cell creation failed")
            return UITableViewCell()
        }
    }

    private func prepareProfileCell(
        _ tableView: UITableView,
        indexPath: IndexPath,
        with viewModel: ProfileOptionViewModelProtocol
    ) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(
            withIdentifier: R.reuseIdentifier.profileCellId,
            for: indexPath
        ) {
            cell.bind(viewModel: viewModel)

            if case .switcher = viewModel.accessoryType {
                if let optionIndex = viewModel.option?.rawValue {
                    cell.switcher.tag = Int(optionIndex)
                }

                cell.switcher.addTarget(
                    self,
                    action: #selector(switcherValueChanged(sender:)),
                    for: .valueChanged
                )
            }

            return cell
        } else {
            assertionFailure("Profile cell creation failed")
            return UITableViewCell()
        }
    }

    private func options(
        for section: SettingsSection,
        viewModel: ProfileViewModelProtocol
    ) -> [ProfileOptionViewModelProtocol] {
        viewModel.profileOptionViewModel.filter { optionViewModel in
            optionViewModel.option.map(section.options.contains) == true
        }
    }
}

extension ProfileViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        SettingsSection.allCases.count
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection _: Int) -> UIView? {
        let footerView = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: tableView.frame.size.width,
                height: Constants.tableViewFooterHeight
            )
        )
        footerView.backgroundColor = R.color.colorBlack()
        return footerView
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        Constants.tableViewFooterHeight
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = state,
              let section = SettingsSection(rawValue: section) else { return 0 }
        switch section {
        case .profile:
            return 2
        case .logout:
            return 1
        default:
            return options(for: section, viewModel: viewModel).count
        }
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        SettingsSection(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .profile:
            switch indexPath.row {
            case 0:
                return prepareProfileSectionCell(tableView, indexPath: indexPath)
            case 1:
                return prepareProfileDetailsCell(tableView, with: viewModel.profileUserViewModel)
            default:
                return UITableViewCell()
            }
        case .logout:
            return prepareProfileCell(tableView, indexPath: indexPath, with: viewModel.logoutViewModel)
        default:
            guard let optionViewModel = options(for: section, viewModel: viewModel)[safe: indexPath.row] else {
                return UITableViewCell()
            }
            return prepareProfileCell(tableView, indexPath: indexPath, with: optionViewModel)
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard SettingsSection(rawValue: indexPath.section) == .profile else {
            return Constants.optionCellHeight
        }
        switch indexPath.row {
        case 0:
            return Constants.sectionCellHeight
        case 1:
            return Constants.detailsCellHeight
        default:
            return Constants.optionCellHeight
        }
    }
}

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return
        }

        if section == .profile {
            if indexPath.row == 1 {
                presenter.activateAccountDetails()
            }
        } else if section == .logout {
            presenter.logout()
        } else if case let .loaded(viewModel) = state,
                  let option = options(for: section, viewModel: viewModel)[safe: indexPath.row]?.option {
            presenter.activateOption(option)
        }
    }
}

extension ProfileViewController: ProfileViewProtocol {
    func didReceive(state: ProfileViewState) {
        self.state = state
        applyState()
    }
}

extension ProfileViewController: Localizable {
    private func setupLocalization() {
        applyState()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension ProfileViewController: WalletsManagmentTableCellDelegate {
    func didTapOptionsCell(with _: IndexPath?) {
        presenter.activateAccountDetails()
    }

    func didTapAccountScore(address: String?) {
        presenter.didTapAccountScore(address: address)
    }
}
