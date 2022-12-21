import UIKit
import SoraFoundation

final class PolkaswapTransaktionSettingsViewController: UIViewController, ViewHolder {
    typealias RootViewType = PolkaswapTransaktionSettingsViewLayout

    // MARK: Private properties

    private let output: PolkaswapTransaktionSettingsViewOutput

    // MARK: - Constructor

    init(
        output: PolkaswapTransaktionSettingsViewOutput,
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
        view = PolkaswapTransaktionSettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindActions()
    }

    // MARK: - Private methods

    private func bindActions() {
        rootView.slippageToleranceSlider.addTarget(
            self,
            action: #selector(handleSliderChangeValue),
            for: .valueChanged
        )
        rootView.selectMarketView.addTarget(
            self,
            action: #selector(handleSelectMatketTapped),
            for: .touchUpInside
        )
        rootView.backButton.addTarget(
            self,
            action: #selector(handleBackButtonTapped),
            for: .touchUpInside
        )
        rootView.selectMarketView.addTarget(
            self,
            action: #selector(handleSelectMatketTapped),
            for: .touchUpInside
        )
        rootView.revertButton.addTarget(
            self,
            action: #selector(handleResetButtonTapped),
            for: .touchUpInside
        )
        rootView.saveButton.addTarget(
            self,
            action: #selector(handleSaveButtonTapped),
            for: .touchUpInside
        )
        rootView.slippageToleranceView.textField.delegate = self
    }

    @objc private func handleSliderChangeValue(sender: UISlider) {
        let value = sender.value
        output.didChangeSlider(value: value)
        rootView.slippageToleranceView.textField.resignFirstResponder()
    }

    @objc private func handleSelectMatketTapped() {
        output.didTapSelectMarket()
    }

    @objc private func handleBackButtonTapped() {
        output.didTapBackButton()
    }

    @objc private func handleSelectMarket() {
        output.didTapSelectMarket()
    }

    @objc private func handleResetButtonTapped() {
        output.didTapResetButton()
    }

    @objc private func handleSaveButtonTapped() {
        output.didTapSaveButton()
    }
}

// MARK: - PolkaswapTransaktionSettingsViewInput

extension PolkaswapTransaktionSettingsViewController: PolkaswapTransaktionSettingsViewInput {
    func didReceive(market: LiquiditySourceType) {
        rootView.bind(market: market.name)
    }

    func didReceive(viewModel: SlippageToleranceViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension PolkaswapTransaktionSettingsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UITextFieldDelegate

extension PolkaswapTransaktionSettingsViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn _: NSRange,
        replacementString string: String
    ) -> Bool {
        if let float = Float(string) {
            output.didChangeSlider(value: float)
        }

        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let slippadgeIsFirstResponder = textField == rootView.slippageToleranceView.textField
        rootView.slippageToleranceView.set(highlighted: slippadgeIsFirstResponder, animated: false)
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.slippageToleranceView.set(highlighted: false, animated: false)
    }
}
