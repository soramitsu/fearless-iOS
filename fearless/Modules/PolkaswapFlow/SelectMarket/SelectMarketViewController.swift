import UIKit
import SoraFoundation

final class SelectMarketViewController: SelectableListViewController<SelectionTitleWithInfoButton> {
    private enum Constants {
        static let cellHeight: CGFloat = 50.0
    }

    // MARK: Private properties

    private let output: SelectMarketViewOutput

    // MARK: - Constructor

    init(
        output: SelectMarketViewOutput,
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
        configure()
    }

    // MARK: - Private methods

    private func setupTableView() {
        rootView.tableView.rowHeight = Constants.cellHeight
        rootView.tableView.backgroundColor = .clear
        rootView.tableView.separatorStyle = .none
    }

    private func setupLayout() {
        rootView.tableView.snp.makeConstraints { make in
            make.height.equalTo(UIScreen.main.bounds.height / 2.5)
        }
    }

    private func configure() {
        rootView.bind(viewModel: nil)
        rootView.backgroundColor = R.color.colorAlmostBlack()
        rootView.titleLabel.text = R.string.localizable
            .polkaswapMarketAlgorithmTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

// MARK: - SelectMarketViewInput

extension SelectMarketViewController: SelectMarketViewInput {}

// MARK: - Localizable

extension SelectMarketViewController: Localizable {
    func applyLocalization() {}
}
