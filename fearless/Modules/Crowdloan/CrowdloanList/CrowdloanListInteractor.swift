import UIKit

final class CrowdloanListInteractor {
    weak var presenter: CrowdloanListInteractorOutputProtocol!
}

extension CrowdloanListInteractor: CrowdloanListInteractorInputProtocol {}
