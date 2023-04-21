import Foundation
import CommonWallet
import IrohaCrypto
import SSFUtils
import RobinHood
import SoraFoundation

final class ContactsLocalSearchEngine: ContactsLocalSearchEngineProtocol {
    let contactViewModelFactory: ContactsFactoryWrapperProtocol
    let addressPrefix: UInt16

    private lazy var addressFactory = SS58AddressFactory()

    init(addressPrefix: UInt16, contactViewModelFactory: ContactsFactoryWrapperProtocol) {
        self.contactViewModelFactory = contactViewModelFactory
        self.addressPrefix = addressPrefix
    }

    func search(
        query: String,
        parameters: ContactModuleParameters,
        locale: Locale,
        delegate: ContactViewModelDelegate?,
        commandFactory: WalletCommandFactoryProtocol
    ) -> [ContactViewModelProtocol]? {
        do {
            let peerId = try addressFactory.accountId(
                fromAddress: query,
                addressPrefix: addressPrefix
            )
            let accountIdData = try Data(hexString: parameters.accountId)

            guard peerId != accountIdData else {
                return []
            }

            let searchData = SearchData(
                accountId: peerId.toHex(),
                firstName: query,
                lastName: ""
            )

            guard let viewModel = contactViewModelFactory
                .createContactViewModelFromContact(
                    searchData,
                    parameters: parameters,
                    locale: locale,
                    delegate: delegate,
                    commandFactory: commandFactory
                )
            else {
                return nil
            }

            return [viewModel]
        } catch {
            return nil
        }
    }
}
