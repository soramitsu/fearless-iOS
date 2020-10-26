import UIKit

final class CommingSoonInteractor {
    weak var presenter: CommingSoonInteractorOutputProtocol!
}

extension CommingSoonInteractor: CommingSoonInteractorInputProtocol {}
