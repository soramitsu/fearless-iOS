import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils

private final class ContactViewModel: ContactsLocalSearchResultProtocol {
    let firstName: String
    let lastName: String
    let accountId: String
    let image: UIImage?
    let name: String
    let command: WalletCommandProtocol?

    init(firstName: String,
         lastName: String,
         accountId: String,
         image: UIImage?,
         name: String,
         command: WalletCommandProtocol?) {
        self.firstName = firstName
        self.lastName = lastName
        self.accountId = accountId
        self.image = image
        self.name = name
        self.command = command
    }
}

final class ContactsLocalSearchEngine: ContactsLocalSearchEngineProtocol {

    weak var commandFactory: WalletCommandFactoryProtocol?

    let networkType: SNAddressType

    private let addressFactory = SS58AddressFactory()

    private let iconGenerator = PolkadotIconGenerator()

    init(networkType: SNAddressType) {
        self.networkType = networkType
    }

    func search(query: String, assetId: String) -> [ContactViewModelProtocol]? {
        do {
            let accountId = try addressFactory.accountId(fromAddress: query, type: networkType)

            let receiver = ReceiveInfo(accountId: accountId.toHex(),
                                       assetId: assetId,
                                       amount: nil,
                                       details: nil)

            let payload = TransferPayload(receiveInfo: receiver,
                                          receiverName: query)

            guard let command = commandFactory?.prepareTransfer(with: payload) else {
                return nil
            }

            command.presentationStyle = .push(hidesBottomBar: true)

            let icon = try iconGenerator.generateFromAddress(query)
                .imageWithFillColor(.white,
                                    size: CGSize(width: 24.0, height: 24.0),
                                    contentScale: UIScreen.main.scale)

            let result = ContactViewModel(firstName: query,
                                          lastName: "",
                                          accountId: receiver.accountId,
                                          image: icon,
                                          name: query,
                                          command: command)

            return [result]
        } catch {
            return nil
        }

    }
}
