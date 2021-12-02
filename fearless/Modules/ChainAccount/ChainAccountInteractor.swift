import UIKit

final class ChainAccountInteractor {
    weak var presenter: ChainAccountInteractorOutputProtocol!
}

extension ChainAccountInteractor: ChainAccountInteractorInputProtocol {}
