import UIKit
import SoraUI
import SoraFoundation

final class AddERC20TokenViewController: UIViewController {
    
    // MARK: - Private properties

    private var output: AddERC20TokenViewOutput?
    private var viewModel: AddERC20TokenViewModel?

    private let tokenAddressField: AnimatedTextField = {
        let field = AnimatedTextField()
        field.textField.autocapitalizationType = .none
        field.textField.autocorrectionType = .no
        field.textField.keyboardType = .asciiCapable
        return field
    }()

    private let tokenNameField: AnimatedTextField = {
        let field = AnimatedTextField()
        field.textField.isEnabled = false
        return field
    }()

    private let tokenSymbolField: AnimatedTextField = {
        let field = AnimatedTextField()
        field.textField.isEnabled = false
        return field
    }()

    private let tokenDecimalsField: AnimatedTextField = {
        let field = AnimatedTextField()
        field.textField.isEnabled = false
        return field
    }()

    private let tokenTotalSupplyField: AnimatedTextField = {
        let field = AnimatedTextField()
        field.textField.isEnabled = false
        return field
    }()

    private let saveButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return stack
    }()

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        return scroll
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        setupActions()
        output?.didLoad(view: self)
    }

    // MARK: - Constructor

    init(
        output: AddERC20TokenViewOutput,
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

    // MARK: - Private methods

    private func setupLayout() {
        view.backgroundColor = R.color.colorBlack()

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(tokenAddressField)
        stackView.addArrangedSubview(tokenNameField)
        stackView.addArrangedSubview(tokenSymbolField)
        stackView.addArrangedSubview(tokenDecimalsField)
        stackView.addArrangedSubview(tokenTotalSupplyField)
        stackView.addArrangedSubview(saveButton)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().priority(.low)
        }

        saveButton.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
    }

    private func setupActions() {
        tokenAddressField.textField.addTarget(
            self,
            action: #selector(tokenAddressChanged),
            for: .editingChanged
        )

        saveButton.addTarget(
            self,
            action: #selector(saveButtonTapped),
            for: .touchUpInside
        )
    }

    @objc private func tokenAddressChanged() {
        output?.didChangeTokenAddress(tokenAddressField.textField.text ?? "")
    }

    @objc private func saveButtonTapped() {
        output?.didTapSave()
    }
}

// MARK: - AddERC20TokenViewInput

extension AddERC20TokenViewController: AddERC20TokenViewInput {
    func didReceive(viewModel: AddERC20TokenViewModel) {
        self.viewModel = viewModel

        tokenAddressField.textField.text = viewModel.tokenAddress
        tokenNameField.textField.text = viewModel.tokenName
        tokenSymbolField.textField.text = viewModel.tokenSymbol
        tokenDecimalsField.textField.text = viewModel.tokenDecimals.map { String($0) }
        tokenTotalSupplyField.textField.text = viewModel.tokenTotalSupply.map { String($0) }

        saveButton.isEnabled = viewModel.isSaveEnabled
        saveButton.applyEnabledStyle()

    }

    func didReceive(isLoading: Bool) {
        if isLoading {
            saveButton.imageWithTitleView?.title = R.string.localizable.commonLoading(preferredLanguages: selectedLocale.rLanguages)
        } else {
            saveButton.imageWithTitleView?.title = R.string.localizable.commonSave(preferredLanguages: selectedLocale.rLanguages)
        }
    }

    func didReceive(error: Error) {
        let message = error.localizedDescription
        let alert = UIAlertController(
            title: R.string.localizable.commonErrorTitle(preferredLanguages: selectedLocale.rLanguages),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: R.string.localizable.commonOk(preferredLanguages: selectedLocale.rLanguages),
            style: .default
        ))
        present(alert, animated: true)
    }
}

extension AddERC20TokenViewController: Localizable {
    func applyLocalization() {
        title = R.string.localizable.addTokenTitle(preferredLanguages: selectedLocale.rLanguages)
        tokenAddressField.title = R.string.localizable.addTokenAddressTitle(preferredLanguages: selectedLocale.rLanguages)
        tokenAddressField.textField.placeholder = R.string.localizable.addTokenAddressPlaceholder(preferredLanguages: selectedLocale.rLanguages)
        tokenNameField.title = R.string.localizable.addTokenNameTitle(preferredLanguages: selectedLocale.rLanguages)
        tokenSymbolField.title = R.string.localizable.addTokenSymbolTitle(preferredLanguages: selectedLocale.rLanguages)
        tokenDecimalsField.title = R.string.localizable.addTokenDecimalsTitle(preferredLanguages: selectedLocale.rLanguages)
        tokenTotalSupplyField.title = R.string.localizable.addTokenTotalSupplyTitle(preferredLanguages: selectedLocale.rLanguages)
        saveButton.imageWithTitleView?.title = R.string.localizable.commonSave(preferredLanguages: selectedLocale.rLanguages)
    }
}
