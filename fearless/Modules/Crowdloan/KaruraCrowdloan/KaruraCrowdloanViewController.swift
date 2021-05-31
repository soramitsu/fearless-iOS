import UIKit

final class KaruraCrowdloanViewController: UIViewController {
    typealias RootViewType = KaruraCrowdloanViewLayout

    let presenter: KaruraCrowdloanPresenterProtocol

    init(presenter: KaruraCrowdloanPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = KaruraCrowdloanViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension KaruraCrowdloanViewController: KaruraCrowdloanViewProtocol {}
