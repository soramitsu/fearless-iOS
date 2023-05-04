import UIKit
import SoraFoundation

final class PhoneVerificationCodeAssembly {
    static func configureModule(with data: SCKYCUserDataModel, otpLength: Int) -> PhoneVerificationCodeModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let service: SCKYCService = .init(client: .shared)
        let interactor = PhoneVerificationCodeInteractor(
            data: data,
            service: service,
            otpLength: otpLength,
            eventCenter: EventCenter.shared,
            tokenHolder: SCTokenHolder.shared
        )
        let router = PhoneVerificationCodeRouter()

        let presenter = PhoneVerificationCodePresenter(
            interactor: interactor,
            router: router,
            phone: data.phoneNumber,
            localizationManager: localizationManager
        )

        let view = PhoneVerificationCodeViewController(
            output: presenter,
            otpLength: otpLength,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
