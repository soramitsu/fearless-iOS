import Foundation
import FearlessUtils

extension Chain {
    var genesisHash: String {
        switch self {
        case .polkadot: return "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        case .kusama: return "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
        case .westend: return "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
        case .rococo: return "1ab7fbd1d7c3532386268ec23fe4ff69f5bb6b3e3697947df3a2ec2786424de3"
        }
    }

    var erasPerDay: Int {
        switch self {
        case .polkadot: return 1
        case .kusama, .westend, .rococo: return 4
        }
    }

    func polkascanExtrinsicURL(_ hash: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkascan.io/polkadot/extrinsic/\(hash)")
        case .kusama:
            return URL(string: "https://polkascan.io/kusama/extrinsic/\(hash)")
        default:
            return nil
        }
    }

    func polkascanAddressURL(_ address: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkascan.io/polkadot/account/\(address)")
        case .kusama:
            return URL(string: "https://polkascan.io/kusama/account/\(address)")
        default:
            return nil
        }
    }

    func polkascanEventURL(_ eventId: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkascan.io/polkadot/event/\(eventId)")
        case .kusama:
            return URL(string: "https://polkascan.io/kusama/event/\(eventId)")
        default:
            return nil
        }
    }

    func subscanExtrinsicURL(_ hash: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkadot.subscan.io/extrinsic/\(hash)")
        case .kusama:
            return URL(string: "https://kusama.subscan.io/extrinsic/\(hash)")
        case .westend:
            return URL(string: "https://westend.subscan.io/extrinsic/\(hash)")
        default:
            return nil
        }
    }

    func subscanAddressURL(_ address: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkadot.subscan.io/account/\(address)")
        case .kusama:
            return URL(string: "https://kusama.subscan.io/account/\(address)")
        case .westend:
            return URL(string: "https://westend.subscan.io/account/\(address)")
        default:
            return nil
        }
    }

    func preparedDefaultTypeDefPath(runtimeMetadata: RuntimeMetadata?) -> String? {
        guard !v14Compatible(runtimeMetadata: runtimeMetadata) else {
            // Runtime compound operation throws error if nothing provided
            return R.file.runtimeEmptyJson.path()
        }

        return R.file.runtimeDefaultJson.path()
    }

    func preparedNetworkTypeDefPath(runtimeMetadata: RuntimeMetadata?) -> String? {
        guard !v14Compatible(runtimeMetadata: runtimeMetadata) else {
            // Runtime compound operation throws error if nothing provided
            return R.file.runtimeEmptyJson.path()
        }

        switch self {
        case .polkadot: return R.file.runtimePolkadotJson.path()
        case .kusama: return R.file.runtimeKusamaJson.path()
        case .westend: return R.file.runtimeWestendJson.path()
        case .rococo: return R.file.runtimeRococoJson.path()
        }
    }

    private func v14Compatible(runtimeMetadata: RuntimeMetadata?) -> Bool {
        guard let runtimeMetadata = runtimeMetadata else { return false }

        let v14SupportedChains: [Self] = [.polkadot, .kusama, .rococo]
        return runtimeMetadata.version >= 14 && v14SupportedChains.contains(self)
    }

    // swiftlint:disable line_length
    func typeDefDefaultFileURL(runtimeMetadata: RuntimeMetadata?) -> URL? {
        let typeDefSuffix = typeDefSuffix(runtimeMetadata: runtimeMetadata)
        return URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-utils/master/scalecodec/type_registry/default\(typeDefSuffix).json")
    }

    private func typeDefSuffix(runtimeMetadata: RuntimeMetadata?) -> String {
        if v14Compatible(runtimeMetadata: runtimeMetadata) {
            return "_v14"
        } else {
            return ""
        }
    }

    func typeDefNetworkFileURL(runtimeMetadata: RuntimeMetadata?) -> URL? {
        let base = URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-utils/master/scalecodec/type_registry")
        let typeDefSuffix = typeDefSuffix(runtimeMetadata: runtimeMetadata)

        switch self {
        case .westend: return base?.appendingPathComponent("westend\(typeDefSuffix).json")
        case .kusama: return base?.appendingPathComponent("kusama\(typeDefSuffix).json")
        case .polkadot: return base?.appendingPathComponent("polkadot\(typeDefSuffix).json")
        case .rococo: return base?.appendingPathComponent("rococo\(typeDefSuffix).json")
        }
    }

    func crowdloanDisplayInfoURL() -> URL {
        let base = URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-utils/master/crowdloan/")!

        switch self {
        case .westend: return base.appendingPathComponent("westend.json")
        case .kusama: return base.appendingPathComponent("kusama.json")
        case .polkadot: return base.appendingPathComponent("polkadot.json")
        case .rococo: return base.appendingPathComponent("rococo.json")
        }
    }
    // swiftlint:enable line_length
}
