import UIKit
import SoraFoundation

final class PolkaswapSwapConfirmationViewController: UIViewController, ViewHolder {
    typealias RootViewType = PolkaswapSwapConfirmationViewLayout

    // MARK: Private properties

    private let output: PolkaswapSwapConfirmationViewOutput

    // MARK: - Constructor

    init(
        output: PolkaswapSwapConfirmationViewOutput,
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
        view = PolkaswapSwapConfirmationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: true)
        output.didLoad(view: self)
        setupActions()
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.backButton.addTarget(
            self,
            action: #selector(handleBackButtonTapped),
            for: .touchUpInside
        )
        rootView.confirmButton.addTarget(
            self,
            action: #selector(handleConfirmButtonTapped),
            for: .touchUpInside
        )
    }

    // MARK: - Private actions

    @objc private func handleBackButtonTapped() {
        output.didTapBackButton()
    }

    @objc private func handleConfirmButtonTapped() {
        output.didTapConfirmButton()
    }
}

// MARK: - PolkaswapSwapConfirmationViewInput

extension PolkaswapSwapConfirmationViewController: PolkaswapSwapConfirmationViewInput {
    func didReceive(viewModel: PolkaswapSwapConfirmationViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didStartLoading() {
        rootView.confirmButton.set(loading: true)
    }

    func didStopLoading() {
        rootView.confirmButton.set(loading: false)
        FWTransferSeal.end(in: view)
    }
}

// MARK: - Localizable

extension PolkaswapSwapConfirmationViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - The seal (kit v4)

extension PolkaswapSwapConfirmationViewController: FWTransferSealShowing {
    /// The loading here is a spinner in the confirm button, so the seal shows above the screen on ink at 72 %.
    func didReachTransferStage(_ stage: FWSealStage) {
        FWTransferSeal.reach(stage, in: view, overlayWhenNoLoader: true)
    }

    func didBreakTransfer() {
        FWTransferSeal.breakSeal(in: view)
    }
}
