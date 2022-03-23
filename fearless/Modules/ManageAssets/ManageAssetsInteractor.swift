import UIKit

final class ManageAssetsInteractor {
    weak var presenter: ManageAssetsInteractorOutputProtocol!
}

extension ManageAssetsInteractor: ManageAssetsInteractorInputProtocol {}