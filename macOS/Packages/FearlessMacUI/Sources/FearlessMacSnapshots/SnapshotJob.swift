import Foundation
import WalletCore
import WalletPreviewSupport
import WalletUI

/// One picture to render: a gallery screen over a preview scenario.
struct SnapshotJob {
    let name: String
    let screen: GalleryScreen
    let scenario: PreviewScenario
    var balancesHidden = false
    var showTestnets = false

    static func scenario(for screen: GalleryScreen) -> PreviewScenario {
        let base: PreviewScenario
        switch screen.start {
        case .firstRun: base = .firstRun
        case .locked: base = .locked
        case .unlockedEmpty: base = .emptyWalletList
        case .unlocked:
            switch screen {
            case .networks: base = .balanceFailure
            case .sendProgress: base = PreviewScenario(transferOutcome: .stallsAfterBroadcast)
            case .sendFailed: base = .transferFailsAtInclusion
            case .sendOutcomeUnknown: base = .transferOutcomeUnknown
            default: base = .standard
            }
        }
        return base.instant()
    }

    /// Every screen once, plus a few variants that show failure and privacy states.
    static let all: [SnapshotJob] = {
        var jobs = GalleryScreen.allCases.map { SnapshotJob(name: $0.slug, screen: $0, scenario: scenario(for: $0)) }
        jobs.append(SnapshotJob(name: "portfolio-network-failure", screen: .portfolio, scenario: PreviewScenario.balanceFailure.instant()))
        jobs.append(SnapshotJob(name: "portfolio-privacy", screen: .portfolio, scenario: PreviewScenario.standard.instant(), balancesHidden: true))
        jobs.append(SnapshotJob(name: "assets-network-failure", screen: .assets, scenario: PreviewScenario.balanceFailure.instant(), showTestnets: true))
        jobs.append(SnapshotJob(name: "send-included", screen: .sendProgress, scenario: PreviewScenario(transferOutcome: .stallsAfterInclusion).instant()))
        return jobs
    }()

    static let inputs = GalleryHost.Inputs(
        password: PreviewWalletServices.samplePassword,
        recipient: PreviewSampleData.sampleRecipientPolkadot,
        wrongNetworkRecipient: PreviewSampleData.sampleRecipientKusama,
        importWords: PreviewWalletServices.samplePhrase(.words12)
    )
}
