import UIKit
import SoraFoundation

final class ValidatorSearchViewController: UIViewController, ViewHolder {
    typealias RootViewType = ValidatorSearchViewLayout

    let presenter: ValidatorSearchPresenterProtocol

    // MARK: - Lifecycle

    init(
        presenter: ValidatorSearchPresenterProtocol,
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
        view = ValidatorSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        setupNavigationBar()

        applyLocalization()

        presenter.setup()
    }

    // MARK: - Private functions

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CustomValidatorCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CustomValidatorListHeaderView.self)
    }

    private func setupNavigationBar() {
        let rightBarButtonItem = UIBarButtonItem(
            title: R.string.localizable
                .commonDone(preferredLanguages: selectedLocale.rLanguages),
            style: .plain,
            target: self,
            action: #selector(tapDoneButton)
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!,
            .font: UIFont.p0Paragraph
        ]

        rightBarButtonItem.setTitleTextAttributes(attributes, for: .normal)
        rightBarButtonItem.setTitleTextAttributes(attributes, for: .highlighted)

        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    // MARK: - Actions

    @objc private func tapDoneButton() {
        #warning("Not implemented")
        // Syncronize models maybe?
    }
}

extension ValidatorSearchViewController: ValidatorSearchViewProtocol {}

extension ValidatorSearchViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        #warning("Not implemented")
        return 0
    }

    func tableView(_: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        #warning("Not implemented")
        return UITableViewCell()
    }
}

extension ValidatorSearchViewController: UITableViewDelegate {}

extension ValidatorSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .commonSearch(preferredLanguages: selectedLocale.rLanguages)
        }
    }
}
