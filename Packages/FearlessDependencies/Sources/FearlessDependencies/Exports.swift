// This target intentionally has no runtime code.
// It aggregates and links external dependencies to centralize pinning.

#if canImport(Web3)
@_exported import Web3
#endif

#if canImport(Web3ContractABI)
@_exported import Web3ContractABI
#endif

#if canImport(Web3PromiseKit)
@_exported import Web3PromiseKit
#endif

#if canImport(Cosmos)
@_exported import Cosmos
#endif

#if canImport(Swime)
@_exported import Swime
#endif

#if canImport(Kingfisher)
@_exported import Kingfisher
#endif

#if canImport(SnapKit)
@_exported import SnapKit
#endif

#if canImport(Reachability)
@_exported import Reachability
#endif

#if canImport(SwiftyBeaver)
@_exported import SwiftyBeaver
#endif

#if canImport(WalletConnect)
@_exported import WalletConnect
#endif

#if canImport(WalletConnectAuth)
@_exported import WalletConnectAuth
#endif

#if canImport(WalletConnectNetworking)
@_exported import WalletConnectNetworking
#endif

#if canImport(WalletConnectPairing)
@_exported import WalletConnectPairing
#endif

#if canImport(Web3Wallet)
@_exported import Web3Wallet
#endif
