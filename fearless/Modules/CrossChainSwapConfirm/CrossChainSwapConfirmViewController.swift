import UIKit
import SoraFoundation

protocol CrossChainSwapConfirmViewOutput: AnyObject {
    func didLoad(view: CrossChainSwapConfirmViewInput)
    func didTapConfirmButton()
}

final class CrossChainSwapConfirmViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = CrossChainSwapConfirmViewLayout

    // MARK: Private properties

    private let output: CrossChainSwapConfirmViewOutput

    // MARK: - Constructor

    init(
        output: CrossChainSwapConfirmViewOutput,
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
        view = CrossChainSwapConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.confirmButton.addAction { [weak self] in
            self?.output.didTapConfirmButton()
        }
    }

    // MARK: - Private methods
}

// MARK: - CrossChainSwapConfirmViewInput

extension CrossChainSwapConfirmViewController: CrossChainSwapConfirmViewInput {
    func didReceive(swapAmountInfoViewModel: SwapAmountInfoViewModel) {
        rootView.bind(swapAmountInfoViewModel: swapAmountInfoViewModel)
    }

    func didReceive(viewModel: CrossChainSwapViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(doubleImageViewModel: PolkaswapDoubleSymbolViewModel) {
        rootView.bind(doubleImageViewModel: doubleImageViewModel)
    }

    func didReceive(feeViewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: feeViewModel)
    }
}

// MARK: - Localizable

extension CrossChainSwapConfirmViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
