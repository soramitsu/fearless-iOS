import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils

final class ContactsViewModelFactory: ContactsFactoryWrapperProtocol {
    private let iconGenerator = PolkadotIconGenerator()

    func createContactViewModelFromContact(_ contact: SearchData,
                                           parameters: ContactModuleParameters,
                                           locale: Locale,
                                           delegate: ContactViewModelDelegate?,
                                           commandFactory: WalletCommandFactoryProtocol)
        -> ContactViewModelProtocol? {
        do {
            guard parameters.accountId != contact.accountId else {
                return nil
            }

            let icon = try iconGenerator.generateFromAddress(contact.firstName)
                .imageWithFillColor(.white,
                                    size: CGSize(width: 24.0, height: 24.0),
                                    contentScale: UIScreen.main.scale)

            return ContactViewModel(firstName: contact.firstName,
                                    lastName: contact.lastName,
                                    accountId: contact.accountId,
                                    image: icon,
                                    name: contact.firstName,
                                    delegate: delegate)
        } catch {
            return nil
        }
    }
}
