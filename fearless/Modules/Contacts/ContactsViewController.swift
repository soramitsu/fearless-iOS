import UIKit
import SoraFoundation

final class ContactsViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    private enum LayoutConstants {
        static let cellHeight: CGFloat = 52
    }

    typealias RootViewType = ContactsViewLayout

    // MARK: Private properties

    private let output: ContactsViewOutput
    private var sections: [ContactsTableSectionModel] = []

    // MARK: - Constructor

    init(
        output: ContactsViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = ContactsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configure()
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isMovingToParent {
            didStartLoading()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        didStopLoading()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(ContactTableCell.self)

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )

        rootView.createButton.addTarget(
            self,
            action: #selector(createButtonClicked),
            for: .touchUpInside
        )
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func createButtonClicked() {
        output.didTapCreateButton()
    }
}

// MARK: - ContactsViewInput

extension ContactsViewController: ContactsViewInput {
    func didReceive(locale: Locale) {
        rootView.locale = locale
    }

    func didReceive(sections: [ContactsTableSectionModel]) {
        guard sections.isNotEmpty else {
            rootView.showEmptyView()
            return
        }
        rootView.emptyView.isHidden = true
        rootView.tableView.isHidden = false
        self.sections = sections
        rootView.tableView.reloadData()
    }

    func didReceive(source: ContactSource) {
        switch source {
        case .token:
            rootView.navigationBar.setTitle(R.string.localizable.walletHistoryTitle_v190(
                preferredLanguages: selectedLocale.rLanguages
            ))
        case .nft:
            rootView.navigationBar.setTitle(R.string.localizable.walletSearchContacts(
                preferredLanguages: selectedLocale.rLanguages
            ))
        }
    }
}

// MARK: - Localizable

extension ContactsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension ContactsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].cellViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(ContactTableCell.self) else {
            return UITableViewCell()
        }

        return cell
    }

    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].name
    }
}

extension ContactsViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard
            let cell = cell as? ContactTableCell
        else {
            return
        }

        cell.bind(to: sections[indexPath.section].cellViewModels[indexPath.row])
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        LayoutConstants.cellHeight
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        output.didSelect(
            address: sections[indexPath.section].cellViewModels[indexPath.row].contactType.address
        )
    }
}
