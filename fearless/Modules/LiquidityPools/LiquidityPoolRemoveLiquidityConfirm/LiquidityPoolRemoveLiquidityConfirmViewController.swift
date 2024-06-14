import UIKit
import SoraFoundation

protocol LiquidityPoolRemoveLiquidityConfirmViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolRemoveLiquidityConfirmViewInput)
    func handleViewAppeared()
    func didTapBackButton()
    func didTapConfirmButton()
}

final class LiquidityPoolRemoveLiquidityConfirmViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = LiquidityPoolRemoveLiquidityConfirmViewLayout

    // MARK: Private properties

    private let output: LiquidityPoolRemoveLiquidityConfirmViewOutput

    // MARK: - Constructor

    init(
        output: LiquidityPoolRemoveLiquidityConfirmViewOutput,
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
        view = LiquidityPoolRemoveLiquidityConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if isBeingPresented || isMovingToParent {
            output.handleViewAppeared()
        }
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.backButton.addTarget(
            self,
            action: #selector(handleTapBackButton),
            for: .touchUpInside
        )

        rootView.confirmButton.addTarget(
            self,
            action: #selector(handleTapConfirmButton),
            for: .touchUpInside
        )
    }

    // MARK: - Private actions

    @objc private func handleTapBackButton() {
        output.didTapBackButton()
    }

    @objc private func handleTapConfirmButton() {
        output.didTapConfirmButton()
    }
}

// MARK: - LiquidityPoolSupplyConfirmViewInput

extension LiquidityPoolRemoveLiquidityConfirmViewController: LiquidityPoolRemoveLiquidityConfirmViewInput {
    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: fee)
    }

    func setButtonLoadingState(isLoading: Bool) {
        rootView.confirmButton.set(loading: isLoading)
    }

    func didUpdating() {
        DispatchQueue.main.async {
            self.rootView.confirmButton.set(enabled: false)
        }
    }

    func didReceiveConfirmViewModel(_ viewModel: LiquidityPoolSupplyConfirmViewModel?) {
        rootView.bind(confirmViewModel: viewModel)
    }
}

// MARK: - Localizable

extension LiquidityPoolRemoveLiquidityConfirmViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
