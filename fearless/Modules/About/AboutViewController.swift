import UIKit
import SoraUI

final class AboutViewController: UIViewController, AdaptiveDesignable {
    private struct Constants {
        static let logoTopOffset: CGFloat = 102.0
        static let tableTopOffset: CGFloat = 279
        static let heightFriction: CGFloat = 0.85
    }

    private enum Row {
        static let height: CGFloat = 48.0

        case website
        case opensource
        case social
        case writeUs
        case terms
        case privacy
    }

    private enum Section: Int, CaseIterable {
        static let height: CGFloat = 68.0

        case about

        var rows: [Row] {
            switch self {
            case .about:
                return [.website, .opensource, .social, .writeUs, .terms, .privacy]
            }
        }
    }

    var presenter: AboutPresenterProtocol!

    var locale: Locale?

    @IBOutlet private var tableView: UITableView!

    @IBOutlet private var logoTop: NSLayoutConstraint!
    @IBOutlet private var tableTop: NSLayoutConstraint!

    private var viewModel: AboutViewModel = AboutViewModel(website: "",
                                                           version: "",
                                                           social: "",
                                                           email: "")

    override func viewDidLoad() {
        super.viewDidLoad()

        adjustLayout()
        configureTableView()

        presenter.setup()
    }

    private func adjustLayout() {
        if isAdaptiveHeightDecreased {
            logoTop.constant = Constants.logoTopOffset * designScaleRatio.height
                * Constants.heightFriction
            tableTop.constant = Constants.tableTopOffset * designScaleRatio.height
                * Constants.heightFriction
        }
    }

    // MARK: UITableView

    private func title(for section: Section) -> String {
        switch section {
        case .about:
            return R.string.localizable.aboutTitle(preferredLanguages: locale?.rLanguages)
        }
    }

    private func configureTableView() {
        tableView.register(R.nib.aboutTitleCell)
        tableView.register(R.nib.aboutDetailsCell)

        let hiddableFooterSize = CGSize(width: tableView.bounds.width, height: 1.0)
        tableView.tableFooterView = UIView(frame: CGRect(origin: .zero,
                                                         size: hiddableFooterSize))
    }

    private func prepareTitleCell(for tableView: UITableView,
                                  indexPath: IndexPath,
                                  title: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.aboutTitleCellId,
                                                 for: indexPath)!

        cell.bind(title: title)

        return cell
    }

    private func prepareDetailsCell(for tableView: UITableView,
                                    indexPath: IndexPath,
                                    title: String,
                                    subtitle: String,
                                    icon: UIImage?) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.aboutDetailsCellId,
                                                 for: indexPath)!

        cell.bind(title: title, subtitle: subtitle, icon: icon)

        return cell
    }
}

extension AboutViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Section(rawValue: section)!.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)!.rows[indexPath.row] {
        case .website:
            return prepareDetailsCell(for: tableView,
                                      indexPath: indexPath,
                                      title: R.string.localizable
                                            .aboutWebsite(preferredLanguages: locale?.rLanguages),
                                      subtitle: viewModel.website,
                                      icon: R.image.iconAboutWeb())
        case .opensource:
            let versionTitle = R.string.localizable
                .aboutVersion(preferredLanguages: locale?.rLanguages) + " " + viewModel.version
            return prepareDetailsCell(for: tableView,
                                         indexPath: indexPath,
                                         title: R.string.localizable
                                            .aboutGithub(preferredLanguages: locale?.rLanguages),
                                         subtitle: versionTitle,
                                         icon: R.image.iconAboutGit())
        case .social:
            return prepareDetailsCell(for: tableView,
                                      indexPath: indexPath,
                                      title: R.string.localizable
                                        .aboutTelegram(preferredLanguages: locale?.rLanguages),
                                      subtitle: viewModel.social,
                                      icon: R.image.iconAboutTg())
        case .writeUs:
            return prepareDetailsCell(for: tableView,
                                      indexPath: indexPath,
                                      title: R.string.localizable
                                            .aboutContactUs(preferredLanguages: locale?.rLanguages),
                                      subtitle: viewModel.email,
                                      icon: R.image.iconAboutEmail())
        case .terms:
            return prepareTitleCell(for: tableView,
                                         indexPath: indexPath,
                                         title: R.string.localizable
                                            .aboutTerms(preferredLanguages: locale?.rLanguages))
        case .privacy:
            return prepareTitleCell(for: tableView,
                                    indexPath: indexPath,
                                    title: R.string.localizable
                                            .aboutPrivacy(preferredLanguages: locale?.rLanguages))
        }
    }
}

extension AboutViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Row.height
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let multiplier = isAdaptiveHeightDecreased ? designScaleRatio.height : 1.0
        return Section.height * multiplier
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let view = UINib(resource: R.nib.aboutHeaderView)
            .instantiate(withOwner: nil, options: nil).first as? AboutHeaderView else {
                return nil
        }

        view.bind(title: title(for: Section(rawValue: section)!))

        return view
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section)!.rows[indexPath.row] {
        case .website:
            presenter.activateWebsite()
        case .opensource:
            presenter.activateOpensource()
        case .social:
            presenter.activateSocial()
        case .writeUs:
            presenter.activateWriteUs()
        case .terms:
            presenter.activateTerms()
        case .privacy:
            presenter.activatePrivacyPolicy()
        }
    }
}

extension AboutViewController: AboutViewProtocol {
    func didReceive(viewModel: AboutViewModel) {
        self.viewModel = viewModel
        tableView.reloadData()
    }
}
