import UIKit
import SoraFoundation

final class BalanceInfoViewController: UIViewController, ViewHolder {
    typealias RootViewType = BalanceInfoViewLayout

    // MARK: Private properties

    private let output: BalanceInfoViewOutput

    // MARK: - Constructor

    init(
        output: BalanceInfoViewOutput,
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
        view = BalanceInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        rootView.didUpdateSkeletonLayout()
    }
}

// MARK: - BalanceInfoViewInput

extension BalanceInfoViewController: BalanceInfoViewInput {
    func didReceiveViewModel(_ viewModel: BalanceInfoViewModel?) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension BalanceInfoViewController: Localizable {
    func applyLocalization() {}
}
