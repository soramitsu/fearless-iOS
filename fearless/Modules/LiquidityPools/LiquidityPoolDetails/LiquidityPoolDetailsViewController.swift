import UIKit
import SoraFoundation

protocol LiquidityPoolDetailsViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolDetailsViewInput)
    func backButtonClicked()
    func supplyButtonClicked()
    func removeButtonClicked()
    func didTapApyInfo()
}

final class LiquidityPoolDetailsViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = LiquidityPoolDetailsViewLayout

    // MARK: Private properties

    private let output: LiquidityPoolDetailsViewOutput

    // MARK: - Constructor

    init(
        output: LiquidityPoolDetailsViewOutput,
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
        view = LiquidityPoolDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        setupActions()
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.backButtonClicked()
        }
        rootView.supplyButton.addAction { [weak self] in
            self?.output.supplyButtonClicked()
        }
        rootView.removeButton.addAction { [weak self] in
            self?.output.removeButtonClicked()
        }

        let tapApyInfo = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapApyInfo)
        )
        rootView.apyView
            .addGestureRecognizer(tapApyInfo)
    }

    @objc private func handleTapApyInfo() {
        output.didTapApyInfo()
    }
}

// MARK: - LiquidityPoolDetailsViewInput

extension LiquidityPoolDetailsViewController: LiquidityPoolDetailsViewInput {
    func bind(viewModel: LiquidityPoolDetailsViewModel?) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension LiquidityPoolDetailsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
