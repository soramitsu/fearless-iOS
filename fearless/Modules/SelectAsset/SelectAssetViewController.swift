import UIKit
import SoraFoundation

final class SelectAssetViewController: SelectableListViewController<SelectAssetCell> {
    private enum Constants {
        static let cellHeight: CGFloat = 50.0
    }

    // MARK: Private properties

    private let output: SelectAssetViewOutput

    // MARK: - Constructor

    init(
        output: SelectAssetViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(listPresenter: output)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupTableView()
        setupLayout()
    }

    // MARK: - Private methods

    private func setupTableView() {
        rootView.tableView.rowHeight = Constants.cellHeight
        rootView.tableView.backgroundColor = .clear
        rootView.tableView.separatorStyle = .none
        rootView.backgroundColor = R.color.colorAlmostBlack()
    }

    private func setupLayout() {
        rootView.tableView.snp.makeConstraints { make in
            make.height.equalTo(UIScreen.main.bounds.height / 2.5)
        }
    }
}

// MARK: - SelectNetworkViewInput

extension SelectAssetViewController: SelectAssetViewInput {}

// MARK: - Localizable

extension SelectAssetViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
