import Foundation

extension Chain {
    var genesisHash: String {
        switch self {
        case .polkadot:
            return "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        case .kusama:
            return "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
        case .westend:
            return "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
        case .rococo:
            return "1ab7fbd1d7c3532386268ec23fe4ff69f5bb6b3e3697947df3a2ec2786424de3"
        case .karura:
            return "baf5aabe40646d11f0ee8abbdc64f4a4b7674925cba08e4a05ff9ebed6e2126b"
        case .moonriver:
            return "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
        case .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha:
            return ""
        }
    }

    var erasPerDay: Int {
        switch self {
        case .polkadot:
            return 1
        case .kusama, .westend, .rococo, .karura, .moonriver, .moonBaseAlpha, .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora:
            return 4
        }
    }

    func polkascanExtrinsicURL(_ hash: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkascan.io/polkadot/extrinsic/\(hash)")
        case .kusama:
            return URL(string: "https://polkascan.io/kusama/extrinsic/\(hash)")
        case .karura:
            return URL(string: "https://polkascan.io/karura/extrinsic/\(hash)")
        case .moonriver:
            return URL(string: "https://polkascan.io/moonriver/extrinsic/\(hash)")
        case .westend, .rococo, .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha:
            return nil
        }
    }

    func polkascanAddressURL(_ address: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkascan.io/polkadot/account/\(address)")
        case .kusama:
            return URL(string: "https://polkascan.io/kusama/account/\(address)")
        case .karura:
            return URL(string: "https://polkascan.io/karura/account/\(address)")
        case .moonriver:
            return URL(string: "https://polkascan.io/moonriver/account/\(address)")
        case .westend, .rococo, .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha:
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
        case .moonriver:
            return URL(string: "https://moonriver.subscan.io/extrinsic/\(hash)")
        case .karura:
            return URL(string: "https://karura.subscan.io/extrinsic/\(hash)")
        case .rococo, .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha:
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
        case .karura:
            return URL(string: "https://karura.subscan.io/account/\(address)")
        case .moonriver:
            return URL(string: "https://monriver.subscan.io/account/\(address)")
        case .rococo, .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha:
            return nil
        }
    }

    var totalRewardURL: URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://api.subquery.network/sq/OnFinality-io/sum-reward")
        case .kusama:
            return URL(string: "https://api.subquery.network/sq/OnFinality-io/sum-reward-kusama")
        case .westend, .rococo, .karura, .moonriver, .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha:
            return nil
        }
    }

    func preparedDefaultTypeDefPath() -> String? {
        R.file.runtimeDefaultJson.path()
    }

    func preparedNetworkTypeDefPath() -> String? {
        switch self {
        case .polkadot:
            return R.file.runtimePolkadotJson.path()
        case .kusama:
            return R.file.runtimeKusamaJson.path()
        case .westend:
            return R.file.runtimeWestendJson.path()
        case .rococo:
            return R.file.runtimeRococoJson.path()
        case .karura:
            return R.file.runtimeKaruraJson.path()
        case .moonriver:
            return R.file.runtimeMoonriverJson.path()
        case .moonBaseAlpha:
            return R.file.runtimeMoonbaseAlphaJson.path()
        case .centrifuge:
            return R.file.runtimeCentrifugeJson.path()
        case .chainX:
            return R.file.runtimeChainxJson.path()
        case .darwinia:
            return R.file.runtimeDawiniaJson.path()
        case .edgeware:
            return R.file.runtimeEdgewareJson.path()
        case .plasm:
            return R.file.runtimePlasmJson.path()
        case .sora:
            return R.file.runtimeSoraJson.path()
        case .subsocial:
            return R.file.runtimeSubsocialJson.path()
        case .kulupu:
            return R.file.runtimeKulupuJson.path()
        }
    }

    // swiftlint:disable line_length
    func typeDefDefaultFileURL() -> URL? {
        URL(string: "https://raw.githubusercontent.com/polkascan/py-scale-codec/master/scalecodec/type_registry/default.json")
    }

    func typeDefNetworkFileURL() -> URL? {
        let base = URL(string: "https://raw.githubusercontent.com/polkascan/py-scale-codec/master/scalecodec/type_registry")

        switch self {
        case .westend:
            return base?.appendingPathComponent("westend.json")
        case .kusama:
            return base?.appendingPathComponent("kusama.json")
        case .polkadot:
            return base?.appendingPathComponent("polkadot.json")
        case .rococo:
            return base?.appendingPathComponent("rococo.json")
        case .karura, .moonriver, .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha:
            return nil
        }
    }

    func crowdloanDisplayInfoURL() -> URL {
        let base = URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-utils/master/crowdloan")!

        switch self {
        case .westend:
            return base.appendingPathComponent("westend.json")
        case .kusama:
            return base.appendingPathComponent("kusama.json")
        case .polkadot:
            return base.appendingPathComponent("polkadot.json")
        case .rococo:
            return base.appendingPathComponent("rococo.json")
        case .karura, .moonriver, .centrifuge, .chainX,
             .darwinia, .edgeware, .kulupu, .plasm, .subsocial, .sora, .moonBaseAlpha:
            return base.appendingPathComponent("kusama.json")
        }
    }
    // swiftlint:enable line_length
}
