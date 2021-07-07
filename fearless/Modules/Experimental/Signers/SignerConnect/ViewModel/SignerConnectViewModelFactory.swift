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
        let iconViewModel = createImageViewModel(from: metadata.icon)

        let accountIcon = try PolkadotIconGenerator().generateFromAddress(account.address)

        let host: String? = {
            guard let appUrl = metadata.appUrl else {
                return nil
            }

            return URL(string: appUrl)?.host
        }()

        return SignerConnectViewModel(
            title: metadata.name,
            icon: iconViewModel,
            connection: host ?? metadata.relayServer,
            accountName: account.username,
            accountIcon: accountIcon
        )
    }

    private func createImageViewModel(from icon: String?) -> ImageViewModelProtocol? {
        let defaultIconClosure: () -> ImageViewModelProtocol? = {
            let defaultIcon = R.image.iconDAppDefault()
            return defaultIcon.map { WalletStaticImageViewModel(staticImage: $0) }
        }

        guard let iconString = icon else {
            return defaultIconClosure()
        }

        if let url = URL(string: iconString) {
            return RemoteImageViewModel(url: url)
        }

        if let data = Data(base64Encoded: iconString), let image = UIImage(data: data) {
            return WalletStaticImageViewModel(staticImage: image)
        }

        return defaultIconClosure()
    }
}
