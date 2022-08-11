import UIKit
import SoraFoundation

final class MainNftContainerViewController: UIViewController, ViewHolder {
    typealias RootViewType = MainNftContainerViewLayout

    // MARK: Private properties

    private let output: MainNftContainerViewOutput

    // MARK: - Constructor

    init(
        output: MainNftContainerViewOutput,
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
        view = MainNftContainerViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - MainNftContainerViewInput

extension MainNftContainerViewController: MainNftContainerViewInput {}

// MARK: - Localizable

extension MainNftContainerViewController: Localizable {
    func applyLocalization() {}
}
