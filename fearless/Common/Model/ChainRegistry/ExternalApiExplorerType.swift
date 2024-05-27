import Foundation
import SSFModels
import SoraFoundation

extension ChainModel.ExternalApiExplorerType {
    func actionTitle() -> LocalizableResource<String?> {
        LocalizableResource { locale in
            switch self {
            case .subscan:
                return R.string.localizable.transactionDetailsViewSubscan(preferredLanguages: locale.rLanguages)
            case .polkascan:
                return R.string.localizable.transactionDetailsViewPolkascan(preferredLanguages: locale.rLanguages)
            case .etherscan:
                return R.string.localizable.transactionDetailsViewEtherscan(preferredLanguages: locale.rLanguages)
            case .reef:
                return R.string.localizable.transactionDetailsViewReefscan(preferredLanguages: locale.rLanguages)
            case .oklink:
                return R.string.localizable.transactionDetailsViewOklink(preferredLanguages: locale.rLanguages)
            case .unknown:
                return nil
            }
        }
    }
}
