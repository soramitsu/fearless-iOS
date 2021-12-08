import UIKit

final class SearchPeopleViewController: UIViewController {
    typealias RootViewType = SearchPeopleViewLayout

    let presenter: SearchPeoplePresenterProtocol

    init(presenter: SearchPeoplePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SearchPeopleViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SearchPeopleViewController: SearchPeopleViewProtocol {}
