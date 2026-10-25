import UIKit

struct PortfolioFundingOption {
    let title: String
    let subtitle: String
    let select: () -> Void
}

/// Each row owns its exact action; displayed names never reconstruct an identity.
final class PortfolioFundingPickerViewController: UITableViewController, UISearchResultsUpdating {
    private let options: [PortfolioFundingOption]
    private var filtered: [PortfolioFundingOption]
    private let locale: Locale
    private var finished = false

    init(title: String, options: [PortfolioFundingOption], locale: Locale) {
        self.options = options
        filtered = options
        self.locale = locale
        super.init(style: .insetGrouped)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = UIColor(named: "fwBgBase")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(cancel)
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = PortfolioStrings.text("common.cancel", locale: locale)
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = PortfolioStrings.text("common.search", locale: locale)
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        filtered.count
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let option = filtered[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = option.title
        content.secondaryText = option.subtitle
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.textProperties.color = UIColor(named: "fwTextPrimary") ?? .label
        content.secondaryTextProperties.color = UIColor(named: "fwTextSecondary") ?? .secondaryLabel
        cell.contentConfiguration = content
        cell.backgroundColor = UIColor(named: "fwSurfaceRaised")
        cell.accessibilityTraits.insert(.button)
        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !finished, let option = filtered[safe: indexPath.row] else { return }
        finished = true
        navigationController?.dismiss(animated: true) { option.select() }
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        filtered = query.isEmpty ? options : options.filter {
            ($0.title + " " + $0.subtitle).range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: locale
            ) != nil
        }
        tableView.reloadData()
    }

    @objc private func cancel() {
        guard !finished else { return }
        finished = true
        navigationController?.dismiss(animated: true)
    }
}
