import UIKit

final class ExperimentalListInteractor {
    weak var presenter: ExperimentalListInteractorOutputProtocol!
}

extension ExperimentalListInteractor: ExperimentalListInteractorInputProtocol {}
