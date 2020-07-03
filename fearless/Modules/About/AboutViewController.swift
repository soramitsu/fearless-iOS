import UIKit

final class AboutViewController: UIViewController {
    private enum Row {
        static let height: CGFloat = 55.0

        case version
        case writeUs
        case opensource
        case terms
        case privacy
    }

    private enum Section: Int, CaseIterable {
        static let height: CGFloat = 35.0

        case software
        case legal

        var rows: [Row] {
            switch self {
            case .software:
                return [.version, .writeUs, .opensource]
            case .legal:
                return [.terms, .privacy]
            }
        }
    }

    var presenter: AboutPresenterProtocol!

    var locale: Locale?

    @IBOutlet private var tableView: UITableView!

    private var version: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        setupLocalization()

        presenter.setup()
    }

    // MARK: UITableView

    private func title(for section: Section) -> String {
        switch section {
        case .software:
            return R.string.localizable.aboutSoftware(preferredLanguages: locale?.rLanguages)
        case .legal:
            return R.string.localizable.aboutLegal(preferredLanguages: locale?.rLanguages)
        }
    }

    private func configureTableView() {
        tableView.register(R.nib.aboutAccessoryTitleCell)
        tableView.register(R.nib.aboutNavigationCell)

        let hiddableFooterSize = CGSize(width: tableView.bounds.width, height: 1.0)
        tableView.tableFooterView = UIView(frame: CGRect(origin: .zero,
                                                         size: hiddableFooterSize))
    }

    private func setupLocalization() {
        title = R.string.localizable.aboutTitle(preferredLanguages: locale?.rLanguages)
    }

    private func prepareAccessoryCell(for tableView: UITableView,
                                      indexPath: IndexPath,
                                      title: String,
                                      subtitle: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.aboutAccessoryTitleCellId,
                                                 for: indexPath)!

        cell.bind(title: title, subtitle: subtitle)

        return cell
    }

    private func prepareNavigationCell(for tableView: UITableView,
                                       indexPath: IndexPath,
                                       title: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.aboutNavigationCellId,
                                                 for: indexPath)!

        cell.bind(title: title)

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
        case .version:
            return prepareAccessoryCell(for: tableView,
                                        indexPath: indexPath,
                                        title: R.string.localizable
                                            .aboutVersion(preferredLanguages: locale?.rLanguages),
                                        subtitle: version)
        case .writeUs:
            return prepareNavigationCell(for: tableView,
                                         indexPath: indexPath,
                                         title: R.string.localizable
                                            .aboutContactUs(preferredLanguages: locale?.rLanguages))
        case .opensource:
            return prepareNavigationCell(for: tableView,
                                         indexPath: indexPath,
                                         title: R.string.localizable
                                            .aboutSourceCode(preferredLanguages: locale?.rLanguages))
        case .terms:
            return prepareNavigationCell(for: tableView,
                                         indexPath: indexPath,
                                         title: R.string.localizable
                                            .aboutTerms(preferredLanguages: locale?.rLanguages))
        case .privacy:
            return prepareNavigationCell(for: tableView,
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
        return Section.height
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
        case .version:
            return
        case .writeUs:
            presenter.activateWriteUs()
        case .opensource:
            presenter.activateOpensource()
        case .terms:
            presenter.activateTerms()
        case .privacy:
            presenter.activatePrivacyPolicy()
        }
    }
}

extension AboutViewController: AboutViewProtocol {
    func didReceive(version: String) {
        self.version = version
        tableView.reloadData()
    }
}
