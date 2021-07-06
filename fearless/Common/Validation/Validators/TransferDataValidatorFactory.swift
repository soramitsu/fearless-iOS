import Foundation
import SoraFoundation

final class TransferDataValidatorFactory: BaseDataValidatingFactoryProtocol {
    weak var view: (Localizable & ControllerBackedProtocol)?
    var basePresentable: BaseErrorPresentable

    init(presentable: BaseErrorPresentable) {
        basePresentable = presentable
    }
}
