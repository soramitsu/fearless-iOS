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
        indexPath: IndexPath,
        with viewModel: ProfileUserViewModelProtocol
    ) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(
            withIdentifier: R.reuseIdentifier.profileDetailsCellId,
            for: indexPath
        ) {
            cell.bind(model: viewModel, icon: R.image.iconBirdGreen())
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
}

extension ProfileViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        2
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
        guard case let .loaded(viewModel) = state else { return 0 }
        switch section {
        case 0:
            return viewModel.profileOptionViewModel.count + 2
        case 1:
            return 1
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                return prepareProfileSectionCell(tableView, indexPath: indexPath)
            case 1:
                return prepareProfileDetailsCell(tableView, indexPath: indexPath, with: viewModel.profileUserViewModel)
            default:
                let optionViewModel = viewModel.profileOptionViewModel[indexPath.row - 2]
                return prepareProfileCell(tableView, indexPath: indexPath, with: optionViewModel)
            }
        case 1:
            return prepareProfileCell(tableView, indexPath: indexPath, with: viewModel.logoutViewModel)
        default:
            assertionFailure("wrong index apth for cell")
            return UITableViewCell()
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
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
        if indexPath.section == 0 {
            if indexPath.row == 1 {
                presenter.activateAccountDetails()
            } else if indexPath.row >= 2 {
                guard
                    case let .loaded(viewModel) = state,
                    let option = viewModel.profileOptionViewModel[indexPath.row - 2].option
                else {
                    return
                }

                presenter.activateOption(option)
            }
        }
        if indexPath.section == 1 {
            presenter.logout()
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
