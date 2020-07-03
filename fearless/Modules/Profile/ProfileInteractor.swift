import Foundation
import SoraKeystore
import IrohaCrypto

enum ProfileInteractorError: Error {
    case invalidUserData
}

final class ProfileInteractor {
	weak var presenter: ProfileInteractorOutputProtocol?

    let settingsManager: SettingsManagerProtocol
    let ss58AddressFactory: SS58AddressFactoryProtocol
    let logger: LoggerProtocol

    init(settingsManager: SettingsManagerProtocol,
         ss58AddressFactory: SS58AddressFactoryProtocol,
         logger: LoggerProtocol) {
        self.settingsManager = settingsManager
        self.ss58AddressFactory = ss58AddressFactory
        self.logger = logger
    }
}

extension ProfileInteractor: ProfileInteractorInputProtocol {
    func setup() {
        do {
            guard let accountId = settingsManager.accountId else {
                throw ProfileInteractorError.invalidUserData
            }

            let publicKey = try SNPublicKey(rawData: accountId)
            let address = try ss58AddressFactory.address(from: publicKey, type: .kusamaMain)

            presenter?.didReceive(userData: UserData(address: address, publicKey: accountId.toHex()))
        } catch {
            presenter?.didReceiveUserDataProvider(error: error)
        }
    }
}
