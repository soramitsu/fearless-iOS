import UIKit

final class NetworkInfoInteractor {
    weak var presenter: NetworkInfoInteractorOutputProtocol!
}

extension NetworkInfoInteractor: NetworkInfoInteractorInputProtocol {}