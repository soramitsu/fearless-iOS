import UIKit

final class WalletChainAccountDashboardViewController: ContainerViewController, AdaptiveFullWidthContent {
    typealias RootViewType = WalletChainAccountDashboardViewLayout

    override var supportsAdaptiveColumns: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    let presenter: WalletChainAccountDashboardPresenterProtocol

    init(presenter: WalletChainAccountDashboardPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletChainAccountDashboardViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension WalletChainAccountDashboardViewController: WalletChainAccountDashboardViewProtocol {}

extension WalletChainAccountDashboardViewController: HiddableBarWhenPushed {}
