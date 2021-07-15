import UIKit

extension Chain {
    func titleForLocale(_: Locale) -> String {
        switch self {
        case .polkadot:
            return "Polkadot"
        case .kusama:
            return "Kusama"
        case .westend:
            return "Westend"
        case .rococo:
            return "Rococo"
        case .karura:
            return "Karura"
        case .moonriver:
            return "Moonriver"
        case .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha, .statemine:
            return ""
        }
    }

    var icon: UIImage? {
        switch self {
        case .polkadot:
            return R.image.iconPolkadotSmallBg()
        case .kusama:
            return R.image.iconKsmSmallBg()
        case .westend:
            return R.image.iconWestendSmallBg()
        case .rococo:
            return R.image.iconKsmSmallBg()
        case .karura:
            return R.image.iconKsmSmallBg()
        case .moonriver:
            return R.image.iconKsmSmallBg()
        case .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha, .statemine:
            return nil
        }
    }

    var extrinsicIcon: UIImage? {
        switch self {
        case .polkadot:
            return R.image.iconPolkadotExtrinsic()
        case .kusama:
            return R.image.iconKusamaExtrinsic()
        case .westend:
            return R.image.iconWestendExtrinsic()
        case .rococo:
            return R.image.iconKusamaExtrinsic()
        case .karura:
            return R.image.iconKusamaExtrinsic()
        case .moonriver:
            return R.image.iconKusamaExtrinsic()
        case .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha, .statemine:
            return nil
        }
    }
}
