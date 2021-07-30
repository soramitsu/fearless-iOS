import UIKit
import SoraFoundation

final class AnalyticsRewardsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsRewardsView

    private let presenter: AnalyticsRewardsPresenterProtocol

    init(presenter: AnalyticsRewardsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsRewardsView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AnalyticsRewardsViewController: AnalyticsRewardsViewProtocol {
    var localizedTitle: LocalizableResource<String> {
        LocalizableResource { _ in
            "Rewards"
        }
    }

    func reload() {}
}
