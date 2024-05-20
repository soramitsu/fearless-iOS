import UIKit
import SoraFoundation
import SnapKit

protocol LiquidityPoolSupplyViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolSupplyViewInput)
    func didTapBackButton()
    func didTapApyInfo()
    func didTapPreviewButton()
    func selectFromAmountPercentage(_ percentage: Float)
    func updateFromAmount(_ newValue: Decimal)
    func selectToAmountPercentage(_ percentage: Float)
    func updateToAmount(_ newValue: Decimal)
    func didTapSelectFromAsset()
    func didTapSelectToAsset()
}

final class LiquidityPoolSupplyViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = LiquidityPoolSupplyViewLayout
    var keyboardHandler: FearlessKeyboardHandler?
    
    private enum Constants {
        static let delay: CGFloat = 0.7
    }
    
    // MARK: Private properties
    private let output: LiquidityPoolSupplyViewOutput
    
    private var amountFromInputViewModel: IAmountInputViewModel?
    private var amountToInputViewModel: IAmountInputViewModel?

    // MARK: - Constructor
    init(
        output: LiquidityPoolSupplyViewOutput,
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
        view = LiquidityPoolSupplyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupActions()
        configure()
        addEndEditingTapGesture(for: rootView.contentView)
    }
    
    // MARK: - Private methods
    
    private func configure() {
        navigationController?.setNavigationBarHidden(true, animated: true)

        rootView.swapToInputView.textField.delegate = self
        rootView.swapFromInputView.textField.delegate = self

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: locale)
        rootView.swapFromInputView.textField.inputAccessoryView = accessoryView
        updatePreviewButton()
    }
    
    private func updatePreviewButton() {
        let isEnabled = amountFromInputViewModel?.isValid == true && amountToInputViewModel?.isValid == true
        rootView.previewButton.set(enabled: isEnabled)
    }
    
    private func setupActions() {
        rootView.backButton.addTarget(
            self,
            action: #selector(handleTapBackButton),
            for: .touchUpInside
        )
        rootView.swapFromInputView.selectHandler = { [weak self] in
            self?.output.didTapSelectFromAsset()
        }
        rootView.swapToInputView.selectHandler = { [weak self] in
            self?.output.didTapSelectToAsset()
        }

        let tapMinReceiveInfo = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapApyInfo)
        )
        rootView.minMaxReceivedView.titleLabel
            .addGestureRecognizer(tapMinReceiveInfo)

        rootView.previewButton.addTarget(
            self,
            action: #selector(handleTapPreviewButton),
            for: .touchUpInside
        )
    }
    
    // MARK: - Private actions

    @objc private func handleTapBackButton() {
        output.didTapBackButton()
    }

    @objc private func handleTapMarketButton() {
        output.didTapMarketButton()
    }

    @objc private func handleTapApyInfo() {
        output.didTapApyInfo()
    }

    @objc private func handleTapPreviewButton() {
        output.didTapPreviewButton()
    }
}

// MARK: - LiquidityPoolSupplyViewInput
extension LiquidityPoolSupplyViewController: LiquidityPoolSupplyViewInput {}

// MARK: - Localizable
extension LiquidityPoolSupplyViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
// MARK: - AmountInputAccessoryViewDelegate

extension LiquidityPoolSupplyViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        if rootView.swapFromInputView.textField.isFirstResponder {
            output.selectFromAmountPercentage(percentage)
        } else if rootView.swapToInputView.textField.isFirstResponder {
            output.selectToAmountPercentage(percentage)
        }
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        if rootView.swapFromInputView.textField.isFirstResponder {
            rootView.swapFromInputView.textField.resignFirstResponder()
        } else if rootView.swapToInputView.textField.isFirstResponder {
            rootView.swapToInputView.textField.resignFirstResponder()
        }
    }
}

// MARK: - UITextFieldDelegate

extension LiquidityPoolSupplyViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if textField == rootView.swapFromInputView.textField {
            return amountFromInputViewModel?.didReceiveReplacement(string, for: range) ?? false
        } else if textField == rootView.swapToInputView.textField {
            return amountToInputViewModel?.didReceiveReplacement(string, for: range) ?? false
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let swapFromIsFirstResponder = textField == rootView.swapFromInputView.textField
        rootView.swapFromInputView.set(highlighted: swapFromIsFirstResponder, animated: false)

        if textField == rootView.swapToInputView.textField, amountToInputViewModel != nil {
            let swapToIsFirstResponder = textField == rootView.swapToInputView.textField
            rootView.swapToInputView.set(highlighted: swapToIsFirstResponder, animated: false)
        } else if textField == rootView.swapToInputView.textField {
            rootView.swapToInputView.textField.resignFirstResponder()
            output.didTapSelectToAsset()
        }
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.swapFromInputView.set(highlighted: false, animated: false)
        rootView.swapToInputView.set(highlighted: false, animated: false)
    }
}

// MARK: - AmountInputViewModelObserver

extension LiquidityPoolSupplyViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.swapFromInputView.inputFieldText = amountFromInputViewModel?.displayAmount
        rootView.swapToInputView.inputFieldText = amountToInputViewModel?.displayAmount

        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(updateAmounts),
            object: nil
        )
        perform(#selector(updateAmounts), with: nil, afterDelay: Constants.delay)
    }

    @objc private func updateAmounts() {
        if rootView.swapFromInputView.textField.isFirstResponder {
            guard let amountFrom = amountFromInputViewModel?.decimalAmount else {
                output.updateFromAmount(0)

                return
            }
            output.updateFromAmount(amountFrom)
        }

        if rootView.swapToInputView.textField.isFirstResponder {
            guard let amountTo = amountToInputViewModel?.decimalAmount else {
                output.updateToAmount(0)

                return
            }
            output.updateToAmount(amountTo)
        }
    }
}

// MARK: - KeyboardViewAdoptable

extension LiquidityPoolSupplyViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { UIConstants.bigOffset }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}
