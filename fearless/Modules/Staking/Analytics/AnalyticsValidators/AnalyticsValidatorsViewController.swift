import UIKit
import SoraFoundation

final class AnalyticsValidatorsViewController: UIViewController {
    typealias RootViewType = AnalyticsValidatorsView

    let presenter: AnalyticsValidatorsPresenterProtocol

    init(presenter: AnalyticsValidatorsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsValidatorsView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AnalyticsValidatorsViewController: AnalyticsValidatorsViewProtocol {
    var localizedTitle: LocalizableResource<String> {
        LocalizableResource { _ in
            "Validators"
        }
    }
}
