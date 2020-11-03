import UIKit

final class AccountExportPasswordInteractor {
    weak var presenter: AccountExportPasswordInteractorOutputProtocol!
}

extension AccountExportPasswordInteractor: AccountExportPasswordInteractorInputProtocol {}