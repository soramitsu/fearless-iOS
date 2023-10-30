import UIKit
import SoraFoundation

protocol ReceiveAndRequestAssetViewOutput: AnyObject {
    func didLoad(view: ReceiveAndRequestAssetViewInput)
    func share(qrImage: UIImage)
    func close()
    func presentAccountOptions()
    func didTapSelectAsset()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
}

final class ReceiveAndRequestAssetViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = ReceiveAndRequestAssetViewLayout

    // MARK: Private properties

    private let output: ReceiveAndRequestAssetViewOutput
    private var amountInputViewModel: IAmountInputViewModel?

    // MARK: - Constructor

    init(
        output: ReceiveAndRequestAssetViewOutput,
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
        view = ReceiveAndRequestAssetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindActions()
        configure()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.amountView.textField.delegate = self
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: locale)
        rootView.amountView.textField.inputAccessoryView = accessoryView
    }

    private func bindActions() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.close()
        }
        rootView.shareButton.addAction { [weak self] in
            if let image = self?.rootView.qrView.qrImageView.image {
                self?.output.share(qrImage: image)
            }
        }
        rootView.copyButton.addAction { [weak self] in
            UIPasteboard.general.string = self?.rootView.addressLabel.text
            self?.output.close()
        }
        rootView.amountView.selectHandler = { [weak self] in
            self?.output.didTapSelectAsset()
        }
    }
}

// MARK: - ReceiveAndRequestAssetViewInput

extension ReceiveAndRequestAssetViewController: ReceiveAndRequestAssetViewInput {
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?) {
        rootView.bind(assetViewModel: assetBalanceViewModel)
    }

    func didReceive(viewModel: ReceiveAssetViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(image: UIImage) {
        rootView.qrView.qrImageView.image = image
    }

    func didReceive(amountInputViewModel: IAmountInputViewModel?) {
        self.amountInputViewModel = amountInputViewModel
        if let amountViewModel = amountInputViewModel {
            amountViewModel.observable.remove(observer: self)
            amountViewModel.observable.add(observer: self)
            rootView.amountView.inputFieldText = amountViewModel.displayAmount
        }
    }
}

// MARK: - Localizable

extension ReceiveAndRequestAssetViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension ReceiveAndRequestAssetViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountView.textField.resignFirstResponder()

        output.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountView.textField.resignFirstResponder()
    }
}

extension ReceiveAndRequestAssetViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountView.inputFieldText = amountInputViewModel?.displayAmount

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        output.updateAmount(amount)
    }
}

extension ReceiveAndRequestAssetViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}
