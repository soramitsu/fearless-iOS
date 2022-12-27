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

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory.default.createSliderAccessoryView(for: self, locale: locale)
        rootView.slippageToleranceView.textField.inputAccessoryView = accessoryView
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
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if string.isEmpty {
            return true
        }
        let oldString = (textField.text ?? "") as NSString
        let candidate = oldString.replacingCharacters(in: range, with: string)
        let regex = try? NSRegularExpression(pattern: "^[0-9]{1}([.]{0,1})?([0-9]{0,2})?$", options: [])
        if regex?.firstMatch(in: candidate, options: [], range: NSRange(location: 0, length: candidate.count)) != nil {
            NSObject.cancelPreviousPerformRequests(
                withTarget: self,
                selector: #selector(didChangeSlider),
                object: nil
            )
            perform(#selector(didChangeSlider), with: nil, afterDelay: 0.7)
            return true
        }
        return false
    }

    @objc private func didChangeSlider() {
        if let float = Float(rootView.slippageToleranceView.textField.text.or("")) {
            output.didChangeSlider(value: float)
        }
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let slippadgeIsFirstResponder = textField == rootView.slippageToleranceView.textField
        rootView.slippageToleranceView.set(highlighted: slippadgeIsFirstResponder, animated: false)
        if textField == rootView.slippageToleranceView.textField {
            textField.text = ""
        }
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.slippageToleranceView.set(highlighted: false, animated: false)
        if rootView.slippageToleranceView.textField.text?.isEmpty == true {
            let value = rootView.slippageToleranceSlider.value
            output.didChangeSlider(value: value)
        }
    }
}

// MARK: - AmountInputAccessoryViewDelegate

extension PolkaswapTransaktionSettingsViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        output.didChangeSlider(value: percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.slippageToleranceView.textField.resignFirstResponder()
    }
}
