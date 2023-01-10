import UIKit
import SoraFoundation

final class PhoneVerificationCodeAssembly {
    static func configureModule(with phone: String) -> PhoneVerificationCodeModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = PhoneVerificationCodeInteractor()
        let router = PhoneVerificationCodeRouter()

        let presenter = PhoneVerificationCodePresenter(
            interactor: interactor,
            router: router,
            phone: phone,
            localizationManager: localizationManager
        )

        let view = PhoneVerificationCodeViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
