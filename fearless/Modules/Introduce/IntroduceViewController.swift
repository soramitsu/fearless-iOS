import UIKit
import SoraFoundation

final class IntroduceViewController: UIViewController, ViewHolder {
    typealias RootViewType = IntroduceViewLayout

    // MARK: Private properties
    private let output: IntroduceViewOutput

    // MARK: - Constructor
    init(
        output: IntroduceViewOutput,
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
        view = IntroduceViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }
    
    // MARK: - Private methods
}

// MARK: - IntroduceViewInput
extension IntroduceViewController: IntroduceViewInput {}

// MARK: - Localizable
extension IntroduceViewController: Localizable {
    func applyLocalization() {}
}
