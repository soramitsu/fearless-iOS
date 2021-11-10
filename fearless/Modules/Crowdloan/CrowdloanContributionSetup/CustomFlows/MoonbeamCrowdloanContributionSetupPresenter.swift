import Foundation
import SoraFoundation

class MoonbeamCrowdloanContributionSetupPresenter: CrowdloanContributionSetupPresenter {
//    private var hasValidEthereumAddress: Bool = false
//    private var ethereumAddress: String?
//
//    private func provideEthereumAddressViewModel() -> InputViewModelProtocol? {
//        guard case .moonbeam = customFlow else { return nil }
//
//        let predicate = NSPredicate.ethereumAddress
//        let inputHandling = InputHandler(value: ethereumAddress ?? "", predicate: predicate)
//        let viewModel = InputViewModel(inputHandler: inputHandling, placeholder: "")
//
//        if inputHandling.completed != hasValidEthereumAddress {
//            refreshFee()
//        }
//
//        hasValidEthereumAddress = inputHandling.completed
//
//        return viewModel
//    }
//
//    func updateEthereumAddress(_ newValue: String) {
//        ethereumAddress = newValue
//        provideEthereumAddressViewModel()
//    }
}
