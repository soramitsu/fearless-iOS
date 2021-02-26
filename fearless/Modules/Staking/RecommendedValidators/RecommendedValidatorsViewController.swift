import UIKit

final class RecommendedValidatorsViewController: UIViewController {
    var presenter: RecommendedValidatorsPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension RecommendedValidatorsViewController: RecommendedValidatorsViewProtocol {}
