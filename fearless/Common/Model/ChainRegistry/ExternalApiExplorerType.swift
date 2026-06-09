import Foundation
import SSFModels
import FearlessFoundation

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
                return ""
            }
        }
    }
}

extension URL {
    var isSoraMetricsExplorer: Bool {
        host?.lowercased() == "sorametrics.org"
    }

    var soraMetricsExplorerTitle: String? {
        isSoraMetricsExplorer ? "SoraMetrics" : nil
    }
}

extension ChainModel.ExternalApiExplorer {
    var isSoraMetricsExplorer: Bool {
        URL(string: url)?.isSoraMetricsExplorer == true
    }

    var displayName: String {
        if isSoraMetricsExplorer {
            return "SoraMetrics"
        }

        return type.rawValue.capitalized
    }

    var supportsTransactionLookup: Bool {
        types.contains(transactionType) || types.contains(.extrinsic) || types.contains(.tx)
    }

    var supportsAccountLookup: Bool {
        types.contains(.account) || types.contains(.address)
    }

    func accountUrl(for address: String) -> URL? {
        let lookupType: ChainModel.SubscanType = types.contains(.account) ? .account : .address
        return explorerUrl(for: address, type: lookupType)
    }

    func actionTitle() -> LocalizableResource<String?> {
        if isSoraMetricsExplorer {
            return LocalizableResource { _ in "SoraMetrics" }
        }

        return type.actionTitle()
    }
}
