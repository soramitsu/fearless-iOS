import Foundation
import FearlessUtils

protocol SignerConnectViewModelFactoryProtocol {
    func createViewModel(
        from metadata: BeaconConnectionInfo,
        account: AccountItem
    ) throws -> SignerConnectViewModel
}

final class SignerConnectViewModelFactory: SignerConnectViewModelFactoryProtocol {
    func createViewModel(
        from metadata: BeaconConnectionInfo,
        account: AccountItem
    ) throws -> SignerConnectViewModel {
        let iconViewModel: ImageViewModelProtocol? = {
            guard let iconString = metadata.icon else {
                return nil
            }

            if let url = URL(string: iconString) {
                return RemoteImageViewModel(url: url)
            } else if let data = Data(base64Encoded: iconString), let image = UIImage(data: data) {
                return WalletStaticImageViewModel(staticImage: image)
            }

            return nil
        }()

        let accountIcon = try PolkadotIconGenerator().generateFromAddress(account.address)

        return SignerConnectViewModel(
            title: metadata.name,
            icon: iconViewModel,
            connection: metadata.relayServer,
            accountName: account.username,
            accountIcon: accountIcon
        )
    }
}
