import UIKit
import SoraFoundation

protocol RawDataViewOutput: AnyObject {
    func didLoad(view: RawDataViewInput)
    func close()
}

final class RawDataViewController: UIViewController, ViewHolder {
    typealias RootViewType = RawDataViewLayout

    // MARK: Private properties

    private let output: RawDataViewOutput

    private let text: String

    // MARK: - Constructor

    init(
        text: String,
        output: RawDataViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.text = text
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
        view = RawDataViewLayout(text: text)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindActions()
    }

    // MARK: - Private methods

    private func bindActions() {
        rootView.closeButton.addAction { [weak self] in
            self?.output.close()
        }
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.close()
        }
    }
}

// MARK: - RawDataViewInput

extension RawDataViewController: RawDataViewInput {}

// MARK: - Localizable

extension RawDataViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
