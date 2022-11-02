import Foundation
import SoraFoundation

class SendDataValidatingFactory: BaseDataValidatingFactoryProtocol {
    weak var view: (Localizable & ControllerBackedProtocol)?
    var basePresentable: BaseErrorPresentable

    init(
        presentable: BaseErrorPresentable
    ) {
        basePresentable = presentable
    }
}
