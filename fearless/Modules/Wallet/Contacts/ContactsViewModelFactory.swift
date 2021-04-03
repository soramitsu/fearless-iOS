import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils
import RobinHood

final class ContactsViewModelFactory: ContactsFactoryWrapperProtocol {
    private let iconGenerator = PolkadotIconGenerator()
    var dataStorageFacade: StorageFacadeProtocol

    init(dataStorageFacade: StorageFacadeProtocol) {
        self.dataStorageFacade = dataStorageFacade
    }

    func createContactViewModelFromContact(
        _ contact: SearchData,
        parameters: ContactModuleParameters,
        locale: Locale,
        delegate: ContactViewModelDelegate?,
        commandFactory: WalletCommandFactoryProtocol
    ) -> ContactViewModelProtocol? {
        do {
            guard parameters.accountId != contact.accountId else {
                return nil
            }

            let icon = try iconGenerator.generateFromAddress(contact.firstName)
                .imageWithFillColor(
                    .white,
                    size: CGSize(width: 24.0, height: 24.0),
                    contentScale: UIScreen.main.scale
                )

            let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
                dataStorageFacade.createRepository()

            let viewModel = ContactViewModel(
                firstName: contact.firstName,
                lastName: contact.lastName,
                accountId: contact.accountId,
                image: icon,
                name: contact.firstName
            )

            let nextAction = { [weak delegate] in
                delegate?.didSelect(contact: viewModel)
                return
            }

            let cancelAction = {
                let hideCommand = commandFactory.prepareHideCommand(with: .pop)
                try? hideCommand.execute()
            }

            viewModel.command = PhishingCheckExecutor(
                commandFactory: commandFactory,
                storage: AnyDataProviderRepository(storage),
                nextAction: nextAction,
                cancelAction: cancelAction,
                locale: locale,
                publicKey: contact.accountId,
                walletAddress: contact.firstName
            )

            return viewModel
        } catch {
            return nil
        }
    }
}
