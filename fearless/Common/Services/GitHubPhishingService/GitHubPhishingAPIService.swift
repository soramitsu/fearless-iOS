import Foundation
import IrohaCrypto
import CoreData
import RobinHood
import SoraFoundation

class GitHubPhishingAPIService: ApplicationServiceProtocol {
    lazy var endPoint: String = { return "https://polkadot.js.org/phishing/address.json" }()

    enum State {
        case throttled
        case active
        case inactive
    }

    enum Result <T> {
        case success(T)
        case error(String)
    }

    private(set) var isThrottled: Bool = true
    private(set) var isActive: Bool = true

    func setup() {
        guard isThrottled else {
            return
        }

        isThrottled = false

        setupConnection()
    }

    func throttle() {
        guard !isThrottled else {
            return
        }

        isThrottled = true

        clearConnection()
    }

    private func setupConnection() {
        // TODO: Hide inside a function or smth.
        getDataWith { (result) in
            switch result {
            case .success(let data):
//                print(data)
                self.processData(data: data)
            case .error(let message):
                print(message) // TODO: replace with log message
            }
        }
    }

    private func clearConnection() {

    }

    struct PhishingWalletItem {
        let source: String
        let address: String

        init(source: String, address: String) {
            self.source = source
            self.address = address
        }
    }

    private func processData(data: [String: AnyObject]) {
        // Delete all objects

        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        for (key, value) in data {
            if let addresses = value as? [String] {
                for address in addresses {
                    // Convert address to key
                    do {
                        let typeRawValue = try SS58AddressFactory().type(fromAddress: address)

                        guard let addressType = SNAddressType(rawValue: typeRawValue.uint8Value) else {
                            continue
                        }

                        let accountId = try SS58AddressFactory().accountId(fromAddress: address,
                                                                           type: addressType)

                        let item = PhishingItem(source: key,
                                                publicKey: accountId.toHex())
//                        item.identifier = accountId.toHex()
//                        item.publicKey = accountId.toHex()
//                        item.source = key

                        let operation = storage.saveOperation({ [item] }, { [] })
                        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .sync)

//                        let item = PhishingWalletItem(source: key, address: accountId.toHex())
                        print(item)

                    } catch {
                        // log errors
                        continue
                    }
                    // Create object
                }
            }
        }

//        let operation = repository.fetchOperation(by: address, options: RepositoryFetchOptions())
//
//        operation.completionBlock = {
//            DispatchQueue.main.async {
//                self.handleAccountItem(result: operation.result)
//            }
//        }
//
//        operationManager.enqueue(operations: [operation], in: .sync)
//    }

        let testPublicKey = "949b1c5ced07ac5da50b0986e13141d6d59d0e06a9d07393e106d67583e6e76d"
        let fetchOperation = storage.fetchOperation(by: testPublicKey,
                                                    options: RepositoryFetchOptions())
        fetchOperation.completionBlock = {
            DispatchQueue.main.async {
                print(fetchOperation.result) // TODO: как-то захэндлить результат
                self.showAlert()
            }
        }
        OperationManagerFacade.sharedManager.enqueue(operations: [fetchOperation], in: .sync)
    }

    func showAlert() {
        let localizationManager = LocalizationManager.shared
        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.walletSendPhishingWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.walletSendPhishingWarningText("HRgJz89P1R5NEaMhaLzXSm9u3GFJiUsda7jXkVNikU8Y5th", preferredLanguages: locale.rLanguages)

        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)

        let continueTitle = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        let continueAction = UIAlertAction(title: continueTitle, style: .default) { _ in
//            try? self.undelyingCommand?.execute()
        }

        alertController.addAction(continueAction)

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let closeAction = UIAlertAction(title: cancelTitle,
                                        style: .cancel,
                                        handler: nil)
        alertController.addAction(closeAction)

//        let presentationCommand = commandFactory?.preparePresentationCommand(for: alertController)
//        presentationCommand?.presentationStyle = .modal(inNavigation: false)
//
//        try? presentationCommand?.execute()
    }

    func getDataWith(completion: @escaping (Result<[String: AnyObject]>) -> Void) {
        guard let url = URL(string: endPoint) else { return }

        URLSession.shared.dataTask(with: url) { (data, _, error) in
            guard error == nil else { return }
            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data,
                                                               options: [.mutableContainers]) as? [String: AnyObject] {

//                    DispatchQueue.main.async {
                        completion(.success(json))
//                    }
                }
            } catch let error {
                completion(.error(error.localizedDescription))
            }
        }.resume()
    }
}
