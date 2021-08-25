import UIKit

final class AnalyticsRewardDetailsViewController: UIViewController {
    typealias RootViewType = AnalyticsRewardDetailsViewLayout

    let presenter: AnalyticsRewardDetailsPresenterProtocol

    init(presenter: AnalyticsRewardDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsRewardDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AnalyticsRewardDetailsViewController: AnalyticsRewardDetailsViewProtocol {}
