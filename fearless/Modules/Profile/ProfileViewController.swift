import UIKit
import SoraFoundation
import FearlessUtils

final class ProfileViewController: UIViewController {
    private enum Constants {
        static let optionCellHeight: CGFloat = 48.0
        static let sectionCellHeight: CGFloat = 56.0
        static let detailsCellHeight: CGFloat = 86.0
        static let headerInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 16, right: 16.0)
        static let tableViewFooterHeight: CGFloat = 40.0
    }

    var presenter: ProfilePresenterProtocol!

    var iconGenerating: IconGenerating?

    @IBOutlet private var tableView: UITableView!

    private(set) var optionViewModels: [ProfileOptionViewModelProtocol] = []
    private(set) var userViewModel: ProfileUserViewModelProtocol?
    private(set) var logoutViewModel: ProfileOptionViewModelProtocol?
    private(set) var userIcon: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        configureTableView()

        presenter.setup()
    }

    private func configureTableView() {
        tableView.register(
            UINib(resource: R.nib.profileTableViewCell),
            forCellReuseIdentifier: R.reuseIdentifier.profileCellId.identifier
        )

        tableView.register(
            UINib(resource: R.nib.profileDetailsTableViewCell),
            forCellReuseIdentifier: R.reuseIdentifier.profileDetailsCellId.identifier
        )

        tableView.register(
            UINib(resource: R.nib.profileSectionTableViewCell),
            forCellReuseIdentifier: R.reuseIdentifier.profileSectionCellId.identifier
        )

        tableView.alwaysBounceVertical = false
    }
}

extension ProfileViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        2
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        Constants.tableViewFooterHeight
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return optionViewModels.count + 2
        case 1:
            return 1
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
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
            case 1:
                if let cell = tableView.dequeueReusableCell(
                    withIdentifier: R.reuseIdentifier.profileDetailsCellId,
                    for: indexPath
                ) {
                    if let userViewModel = userViewModel {
                        cell.bind(model: userViewModel, icon: userIcon)
                    }

                    return cell
                } else {
                    assertionFailure("Profile details cell creation failed")
                    return UITableViewCell()
                }
            default:
                if let cell = tableView.dequeueReusableCell(
                    withIdentifier: R.reuseIdentifier.profileCellId,
                    for: indexPath
                ) {
                    cell.bind(viewModel: optionViewModels[indexPath.row - 2])

                    return cell
                } else {
                    assertionFailure("Profile cell creation failed")
                    return UITableViewCell()
                }
            }
        case 1:
            if let cell = tableView.dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.profileCellId,
                for: indexPath
            ), let logoutViewModel = logoutViewModel {
                cell.bind(viewModel: ProfileOptionViewModel(
                    title: logoutViewModel.title,
                    icon: logoutViewModel.icon,
                    accessoryTitle: nil
                ))
                return cell
            } else {
                assertionFailure("Profile cell creation failed")
                return UITableViewCell()
            }
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
                presenter.activateOption(at: UInt(indexPath.row) - 2)
            }
        }
        if indexPath.section == 1 {
            presenter.logout()
        }
    }
}

extension ProfileViewController: ProfileViewProtocol {
    func didLoad(userViewModel: ProfileUserViewModelProtocol) {
        self.userViewModel = userViewModel
        userIcon = R.image.iconBirdGreen()
        tableView.reloadData()
    }

    func didLoad(
        optionViewModels: [ProfileOptionViewModelProtocol],
        logoutViewModel: ProfileOptionViewModelProtocol
    ) {
        self.optionViewModels = optionViewModels
        self.logoutViewModel = logoutViewModel
        tableView.reloadData()
    }
}

extension ProfileViewController: Localizable {
    private func setupLocalization() {
        tableView.reloadData()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
