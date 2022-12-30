import Foundation
import FearlessUtils

extension Chain {
    var genesisHash: String {
        switch self {
        case .polkadot: return "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        case .kusama: return "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
        case .westend: return "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
        case .rococo: return "1ab7fbd1d7c3532386268ec23fe4ff69f5bb6b3e3697947df3a2ec2786424de3"
        case .moonbeam: return "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d"
        case .moonriver: return "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
        case .moonbaseAlpha: return "91bc6e169807aaa54802737e1c504b2577d4fafedd5a02c10293b1cd60e39527"
        }
    }

    var erasPerDay: Int {
        switch self {
        case .polkadot: return 1
        case .kusama, .westend, .rococo, .moonbeam: return 4
        case .moonriver, .moonbaseAlpha: return 12
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

    func subscanBlockURL(_ block: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkadot.subscan.io/block/\(block)")
        case .kusama:
            return URL(string: "https://kusama.subscan.io/block/\(block)")
        case .westend:
            return URL(string: "https://westend.subscan.io/block/\(block)")
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

    var analyticsURL: URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet")
        case .kusama:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet-ksm")
        case .westend:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet-westend")
        default:
            return nil
        }
    }

    // MARK: - Local types

    func preparedDefaultTypeDefPath() -> String? {
        R.file.runtimeEmptyJson.path()
    }

    func preparedNetworkTypeDefPath() -> String? {
        R.file.runtimeEmptyJson.path()
    }

    // MARK: - Remote types

    private func utilsUrl(adding pathComponent: String) -> URL? {
        let urlString = "https://raw.githubusercontent.com/soramitsu/fearless-utils/"
        let url = URL(string: urlString)
        return url?.appendingPathComponent(pathComponent)
    }

    private var remoteRegistryBranch: String {
        "master"
    }

    private func remoteTypeRegistryUrl(for file: String) -> URL? {
        utilsUrl(adding: "\(remoteRegistryBranch)/type_registry")?.appendingPathComponent(file)
    }

    func typeDefDefaultFileURL() -> URL? {
        switch self {
        case .rococo: return remoteTypeRegistryUrl(for: "default.json")
        default: return remoteTypeRegistryUrl(for: "empty.json")
        }
    }

    func typeDefNetworkFileURL() -> URL? {
        switch self {
        case .westend: return remoteTypeRegistryUrl(for: "westend.json")
        case .kusama: return remoteTypeRegistryUrl(for: "kusama.json")
        case .polkadot: return remoteTypeRegistryUrl(for: "polkadot.json")
        case .rococo: return remoteTypeRegistryUrl(for: "rococo.json")
        default: return nil
        }
    }

    // MARK: - Crowdloans

    func crowdloanDisplayInfoURL() -> URL {
        let base = utilsUrl(adding: "master/crowdloan")!

        switch self {
        case .westend: return base.appendingPathComponent("westend.json")
        case .kusama: return base.appendingPathComponent("kusama.json")
        case .polkadot: return base.appendingPathComponent("polkadot.json")
        case .rococo: return base.appendingPathComponent("rococo.json")
        default: return base
        }
    }
}
