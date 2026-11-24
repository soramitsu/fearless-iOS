import Foundation
import WalletCore

/// Switches for the in-memory services: where the vault starts, which
/// wallets exist and which failures to simulate.
public struct PreviewScenario: Sendable {
    public enum VaultStart: Sendable {
        /// First launch: no app password yet.
        case uninitialized
        case locked
        case unlocked
    }

    public enum WalletSet: Sendable {
        /// No wallets (the vault is set up but empty).
        case none
        /// Three wallets: one backed up, one not backed up, one watch-only.
        case standard
    }

    public enum TransferOutcome: Sendable {
        /// Signed, broadcast, included, finalized.
        case succeeds
        /// Signed and broadcast, then fails when the block is built.
        case failsAtInclusion
        /// Signed and broadcast, then waits until cancelled (for snapshots of a transfer in flight).
        case stallsAfterBroadcast
        /// Signed, broadcast and included, then waits until cancelled.
        case stallsAfterInclusion
        /// Signed and broadcast, then the connection is lost: the outcome is unknown.
        case outcomeUnknownAfterBroadcast
    }

    public enum Latency: Sendable {
        /// Answers at once (snapshots, tests).
        case none
        /// A few hundred milliseconds, like a healthy network.
        case realistic
        /// Seconds, to look at loading states.
        case slow

        var seconds: ClosedRange<Double> {
            switch self {
            case .none: return 0...0
            case .realistic: return 0.15...0.6
            case .slow: return 1.5...3.5
            }
        }
    }

    public var vault: VaultStart
    public var wallets: WalletSet
    /// Chains whose balances (and transfer preparation) fail.
    public var failingChains: Set<ChainID>
    /// Chains whose history cannot be loaded.
    public var historyUnavailableChains: Set<ChainID>
    public var transferOutcome: TransferOutcome
    public var latency: Latency
    public var biometrics: BiometricsAvailability
    /// True when the price feed fails.
    public var pricesFail: Bool
    /// The app password of the sample vault (ignored for `.uninitialized`).
    public var password: String

    public init(
        vault: VaultStart = .unlocked,
        wallets: WalletSet = .standard,
        failingChains: Set<ChainID> = [],
        historyUnavailableChains: Set<ChainID> = [],
        transferOutcome: TransferOutcome = .succeeds,
        latency: Latency = .realistic,
        biometrics: BiometricsAvailability = .available,
        pricesFail: Bool = false,
        password: String = PreviewWalletServices.samplePassword
    ) {
        self.vault = vault
        self.wallets = wallets
        self.failingChains = failingChains
        self.historyUnavailableChains = historyUnavailableChains
        self.transferOutcome = transferOutcome
        self.latency = latency
        self.biometrics = biometrics
        self.pricesFail = pricesFail
        self.password = password
    }

    /// Unlocked, three wallets, everything healthy.
    public static let standard = PreviewScenario()
    /// First launch.
    public static let firstRun = PreviewScenario(vault: .uninitialized, wallets: .none)
    /// Locked vault with wallets, Touch ID enabled.
    public static let locked = PreviewScenario(vault: .locked, biometrics: .enabled)
    /// Unlocked vault with no wallets.
    public static let emptyWalletList = PreviewScenario(wallets: .none)
    /// Kusama's balances fail; everything else loads.
    public static let balanceFailure = PreviewScenario(
        failingChains: [PreviewCatalog.kusama.id],
        historyUnavailableChains: [PreviewCatalog.kusama.id]
    )
    /// Transfers fail when the block is built.
    public static let transferFailsAtInclusion = PreviewScenario(transferOutcome: .failsAtInclusion)
    /// Transfers are broadcast, then the node connection is lost before they are confirmed.
    public static let transferOutcomeUnknown = PreviewScenario(transferOutcome: .outcomeUnknownAfterBroadcast)

    /// The same scenario answering at once.
    public func instant() -> PreviewScenario {
        var copy = self
        copy.latency = .none
        return copy
    }
}
