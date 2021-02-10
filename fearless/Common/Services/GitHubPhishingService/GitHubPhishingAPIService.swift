import Foundation
import IrohaCrypto
import CoreData
import RobinHood
import SoraFoundation
import CommonWallet

class GitHubPhishingAPIService: ApplicationServiceProtocol {
    lazy var endPoint: String = { return "https://polkadot.js.org/phishing/address.json" }()

    let scamAddressProcessor: ScamAddressRepositoryFacadeProtocol = ScamAddressProcessor()
    let logger = Logger.shared

    enum State {
        case throttled
        case active
        case inactive
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
        getDataWith { (result) in
            switch result {
            case .success(let data):
                self.processData(data: data)
            case .failure(let message):
                self.logger.error("Problem retreiving scam addresses: \(message)")
            }
        }
    }

    private func clearConnection() {

    }

    func getDataWith(completion: @escaping (Result<[String: AnyObject], Error>) -> Void) {
        guard let url = URL(string: endPoint) else { return }

        URLSession.shared.dataTask(with: url) { (data, _, error) in
            guard error == nil else { return }
            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data,
                                                               options: [.mutableContainers]) as? [String: AnyObject] {

                    DispatchQueue.main.async {
                        completion(.success(json))
                    }
                }
            } catch let error {
                completion(.failure(error))
            }
        }.resume()
    }

    private func processData(data: [String: AnyObject]) {
        let scamAddressProcessor = ScamAddressProcessor()
        scamAddressProcessor.updateRepository(from: data)
    }

//
//    func showAlert() {
//        let localizationManager = LocalizationManager.shared
//        let locale = localizationManager.selectedLocale
//
//        let title = R.string.localizable.walletSendPhishingWarningTitle(preferredLanguages: locale.rLanguages)
//        let message = R.string.localizable.walletSendPhishingWarningText("HRgJz89P1R5NEaMhaLzXSm9u3GFJiUsda7jXkVNikU8Y5th", preferredLanguages: locale.rLanguages)
//
//        let alertController = UIAlertController(title: title,
//                                                message: message,
//                                                preferredStyle: .alert)
//
//        let continueTitle = R.string.localizable
//            .commonContinue(preferredLanguages: locale.rLanguages)
//
//        let continueAction = UIAlertAction(title: continueTitle, style: .default) { _ in
//            //            try? self.undelyingCommand?.execute()
//        }
//
//        alertController.addAction(continueAction)
//
//        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
//        let closeAction = UIAlertAction(title: cancelTitle,
//                                        style: .cancel,
//                                        handler: nil)
//        alertController.addAction(closeAction)
//
//        //        let presentationCommand = commandFactory?.preparePresentationCommand(for: alertController)
//        //        presentationCommand?.presentationStyle = .modal(inNavigation: false)
//        //
//        //        try? presentationCommand?.execute()
//    }
//
}
