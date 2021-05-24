import UIKit

final class SelectValidatorsViewController: UIViewController {
    typealias RootViewType = SelectValidatorsViewLayout

    let presenter: SelectValidatorsPresenterProtocol

    init(presenter: SelectValidatorsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SelectValidatorsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SelectValidatorsViewController: SelectValidatorsViewProtocol {}
