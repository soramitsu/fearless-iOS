import Foundation
import FearlessUtils

protocol CrowdloanAgreementViewModelFactoryProtocol {
    func createAccountViewModel(
        from displayAddress: DisplayAddress
    ) throws -> CrowdloanAccountViewModel
}

class CrowdloanAgreementViewModelFactory: CrowdloanAgreementViewModelFactoryProtocol {
    private let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func createAccountViewModel(from displayAddress: DisplayAddress) throws -> CrowdloanAccountViewModel {
        let senderIcon = try iconGenerator.generateFromAddress(displayAddress.address)
        let senderName = !displayAddress.username.isEmpty ?
            displayAddress.username : displayAddress.address

        return CrowdloanAccountViewModel(
            accountName: senderName,
            accountIcon: senderIcon
        )
    }
}
