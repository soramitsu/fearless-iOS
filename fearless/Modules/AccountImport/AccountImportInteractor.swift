import UIKit

final class AccountImportInteractor {
    weak var presenter: AccountImportInteractorOutputProtocol!
}

extension AccountImportInteractor: AccountImportInteractorInputProtocol {}