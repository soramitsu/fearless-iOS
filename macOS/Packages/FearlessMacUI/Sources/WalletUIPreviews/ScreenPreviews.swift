#if DEBUG
import DesignSystem
import SwiftUI
import WalletCore
import WalletPreviewSupport
import WalletUI

/// Xcode canvas previews of the main screens over the in-memory services.
/// They use `PreviewProvider` so the package also builds with plain
/// `swift build`.
@MainActor
enum PreviewFactory {
    static let inputs = GalleryHost.Inputs(
        password: PreviewWalletServices.samplePassword,
        recipient: PreviewSampleData.sampleRecipientPolkadot,
        wrongNetworkRecipient: PreviewSampleData.sampleRecipientKusama,
        importWords: PreviewWalletServices.samplePhrase(.words12)
    )

    static func scenario(for screen: GalleryScreen) -> PreviewScenario {
        let base: PreviewScenario
        switch screen.start {
        case .firstRun: base = .firstRun
        case .locked: base = .locked
        case .unlockedEmpty: base = .emptyWalletList
        case .unlocked: base = screen == .networks ? .balanceFailure : .standard
        }
        return base.instant()
    }

    static func view(_ screen: GalleryScreen) -> some View {
        let defaults = UserDefaults(suiteName: "fearless.previews.\(screen.rawValue)") ?? .standard
        return GalleryView(
            screen: screen,
            services: PreviewWalletServices.make(scenario: scenario(for: screen)),
            settings: AppSettings(defaults: defaults),
            inputs: inputs
        )
    }
}

struct MainWindow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PreviewFactory.view(.portfolio).previewDisplayName("Portfolio")
            PreviewFactory.view(.assets).previewDisplayName("Assets")
            PreviewFactory.view(.activity).previewDisplayName("Activity")
            PreviewFactory.view(.networks).previewDisplayName("Networks")
        }
        .frame(width: 1180, height: 760)
    }
}

struct Onboarding_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PreviewFactory.view(.onboardingWelcome).previewDisplayName("Welcome")
            PreviewFactory.view(.onboardingPassword).previewDisplayName("App password")
            PreviewFactory.view(.onboardingPhraseReveal).previewDisplayName("New phrase")
            PreviewFactory.view(.onboardingPhraseImport).previewDisplayName("Import phrase")
            PreviewFactory.view(.lock).previewDisplayName("Lock")
        }
        .frame(width: 1100, height: 720)
    }
}

struct Sheets_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PreviewFactory.view(.sendFormIssue).previewDisplayName("Send, with issues")
            PreviewFactory.view(.sendReview).previewDisplayName("Send, review")
            PreviewFactory.view(.sendFinalized).previewDisplayName("Send, final")
            PreviewFactory.view(.receive).previewDisplayName("Receive")
        }
    }
}

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PreviewFactory.view(.settingsGeneral).previewDisplayName("General")
            PreviewFactory.view(.settingsSecurity).previewDisplayName("Security")
            PreviewFactory.view(.settingsWallets).previewDisplayName("Wallets")
            PreviewFactory.view(.settingsNetworks).previewDisplayName("Networks")
            PreviewFactory.view(.menuBarExtra).previewDisplayName("Menu bar extra")
        }
    }
}

struct DesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            HStack(spacing: 24) {
                SealView(stage: .sent)
                SealView(stage: .finalized)
                SealView(stage: .accepted, failed: true)
            }
            HStack(spacing: 24) {
                SyncDial(done: 5, failed: 1, total: 9, size: 36)
                SyncDial(done: 8, failed: 1, total: 9, size: 36)
                CometLoader(size: 48)
                CrestBadge(size: 64)
            }
        }
        .padding(32)
        .previewDisplayName("Shikiban figures")
    }
}
#endif
