import UIKit
import SoraFoundation

protocol LiquidityPoolSupplyConfirmViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolSupplyConfirmViewInput)
    func handleViewAppeared()
    func didTapBackButton()
    func didTapApyInfo()
    func didTapConfirmButton()
}

final class LiquidityPoolSupplyConfirmViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = LiquidityPoolSupplyConfirmViewLayout

    // MARK: Private properties

    private let output: LiquidityPoolSupplyConfirmViewOutput

    // MARK: - Constructor

    init(
        output: LiquidityPoolSupplyConfirmViewOutput,
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
        view = LiquidityPoolSupplyConfirmViewLayout()
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

    @objc private func handleTapApyInfo() {
        output.didTapApyInfo()
    }

    @objc private func handleTapConfirmButton() {
        output.didTapConfirmButton()
    }
}

// MARK: - LiquidityPoolSupplyConfirmViewInput

extension LiquidityPoolSupplyConfirmViewController: LiquidityPoolSupplyConfirmViewInput {
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

    func didReceiveViewModel(_ viewModel: LiquidityPoolSupplyViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceiveConfirmationViewModel(_ viewModel: LiquidityPoolSupplyConfirmViewModel?) {
        rootView.bind(confirmViewModel: viewModel)
    }
}

// MARK: - Localizable

extension LiquidityPoolSupplyConfirmViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
