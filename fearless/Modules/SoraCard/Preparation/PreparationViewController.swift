import UIKit
import SoraFoundation

final class PreparationViewController: UIViewController, ViewHolder {
    typealias RootViewType = PreparationViewLayout

    // MARK: Private properties

    private let output: PreparationViewOutput

    // MARK: - Constructor

    init(
        output: PreparationViewOutput,
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
        view = PreparationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - PreparationViewInput

extension PreparationViewController: PreparationViewInput {}

// MARK: - Localizable

extension PreparationViewController: Localizable {
    func applyLocalization() {}
}
