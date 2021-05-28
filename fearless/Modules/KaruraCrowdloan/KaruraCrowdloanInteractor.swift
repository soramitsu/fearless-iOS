import UIKit

final class KaruraCrowdloanInteractor {
    weak var presenter: KaruraCrowdloanInteractorOutputProtocol!
}

extension KaruraCrowdloanInteractor: KaruraCrowdloanInteractorInputProtocol {}
