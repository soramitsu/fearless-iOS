import Foundation
import os
import Testing
import WalletCore
@testable import WalletPreviewSupport
@testable import WalletUI

@MainActor
@Suite("Settings")
struct SettingsTests {
    @Test func preferencesPersistInTheirDefaultsSuite() {
        let suite = "fearless.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = AppSettings(defaults: defaults)
        #expect(first.fiat == .usd)
        #expect(first.appearance == .system)
        #expect(!first.menuBarExtraEnabled, "the menu bar extra is off until the user turns it on")
        #expect(!first.showTestnets)
        first.fiatCode = "jpy"
        first.appearance = .dark
        first.balancesHidden = true
        first.menuBarExtraEnabled = true
        first.setHidden(true, assetID: PreviewCatalog.eth.id)
        first.autoLockMinutes = 15

        let second = AppSettings(defaults: defaults)
        #expect(second.fiat == .jpy)
        #expect(second.appearance == .dark)
        #expect(second.balancesHidden)
        #expect(second.menuBarExtraEnabled)
        #expect(second.isHidden(PreviewCatalog.eth.id))
        #expect(second.autoLockMinutes == 15)
        second.fiatCode = "xyz"
        #expect(second.fiat == .usd, "an unknown code falls back to the US dollar")
    }

    @Test func settingTheSameValueChangesNothing() {
        let suite = "fearless.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)

        // Observation calls `onChange` synchronously, before the value changes.
        let fired = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = settings.balancesHidden
            _ = settings.menuBarExtraEnabled
        } onChange: {
            fired.withLock { $0 = true }
        }
        settings.balancesHidden = false
        settings.hiddenAssetKeys = []
        settings.selectedWalletID = nil
        settings.menuBarExtraEnabled = false
        settings.autoLockMinutes = 5
        settings.forgetWalletState()
        #expect(!fired.withLock { $0 }, "writes of the same value never notify observers")
        #expect(defaults.persistentDomain(forName: suite) == nil, "unchanged values are not written")

        settings.balancesHidden = true
        #expect(fired.withLock { $0 }, "a real change does notify")
        #expect(defaults.bool(forKey: "fearless.ui.balancesHidden"))
    }

    @Test func theMenuBarFlagIsObservedApartFromOtherSettings() {
        let settings = makeSettings()
        let fired = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = settings.menuBarExtraEnabled
        } onChange: {
            fired.withLock { $0 = true }
        }
        settings.balancesHidden = true
        settings.fiatCode = "eur"
        settings.setHidden(true, assetID: PreviewCatalog.eth.id)
        #expect(!fired.withLock { $0 }, "the scene list depends on the menu bar flag only")
        settings.menuBarExtraEnabled = true
        #expect(fired.withLock { $0 })
    }

    @Test func scenesBuildTheirModelOnceAndOnlyWhenNeeded() {
        let builds = Box(0)
        let services = PreviewWalletServices.make(scenario: PreviewScenario.standard.instant())
        let settings = makeSettings()
        // SwiftUI re-creates the scenes value whenever the app's body runs.
        let stores = (0..<5).map { _ in
            SceneModelStore {
                builds.value += 1
                return AppModel(services: services, settings: settings)
            }
        }
        #expect(builds.value == 0, "creating the scenes has no side effects")
        let first = stores[0].model
        #expect(stores[0].model === first)
        #expect(builds.value == 1)
    }

    @Test func nothingSecretIsEverWrittenToDefaults() async throws {
        let suite = "fearless.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        let app = AppModel(services: PreviewWalletServices.make(scenario: PreviewScenario.firstRun.instant()), settings: settings)
        app.start(monitorSystem: false)
        #expect(await waitUntil { app.onboarding != nil })
        let model = try #require(app.onboarding)
        await model.choose(.create)
        model.password = PreviewWalletServices.samplePassword
        model.passwordConfirmation = PreviewWalletServices.samplePassword
        await model.submitPassword()
        await model.skipBiometrics()
        let phrase = model.phrase
        #expect(phrase.count == 12)
        await model.backUpLater()
        await model.finish()
        #expect(await waitUntil { app.route == .main && app.selectedWallet != nil })
        app.settings.balancesHidden = true
        app.hideAsset(PreviewCatalog.eth.id)

        let stored = defaults.persistentDomain(forName: suite) ?? [:]
        let text = String(describing: stored)
        #expect(!text.contains(PreviewWalletServices.samplePassword))
        for word in phrase {
            #expect(!text.contains(word), "a phrase word reached UserDefaults")
        }
        #expect(!stored.isEmpty)
        #expect(stored.keys.allSatisfy { $0.hasPrefix("fearless.ui.") })
    }

    @Test func securityModelChangesThePasswordOnlyWhenTheFormIsSound() async {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.standard.instant())
        let model = SecuritySettingsModel(vault: services.vault)
        await model.load()
        #expect(!model.biometricsEnabled)
        #expect(model.biometricsUnavailableReason == nil)

        model.currentPassword = PreviewWalletServices.samplePassword
        model.newPassword = "weak"
        model.newPasswordConfirmation = "weak"
        #expect(!model.canChangePassword)
        model.newPassword = "Brand-New-Password-7"
        model.newPasswordConfirmation = "Brand-New-Password-8"
        #expect(model.passwordMismatchMessage != nil)
        #expect(!model.canChangePassword)
        model.newPasswordConfirmation = "Brand-New-Password-7"
        #expect(model.canChangePassword)

        model.currentPassword = "not it"
        await model.changePassword()
        #expect(model.passwordError == WalletError.wrongPassword.errorDescription)
        #expect(!model.passwordChanged)

        model.currentPassword = PreviewWalletServices.samplePassword
        await model.changePassword()
        #expect(model.passwordChanged)
        #expect(model.newPassword.isEmpty)
        await services.vault.lock()
        await #expect(throws: WalletError.wrongPassword) {
            try await services.vault.unlock(.password(PreviewWalletServices.samplePassword))
        }
        try? await services.vault.unlock(.password("Brand-New-Password-7"))
        #expect(await services.vault.state() == .unlocked)
    }

    @Test func touchIDSwitchAsksForThePassword() async {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.standard.instant())
        let model = SecuritySettingsModel(vault: services.vault)
        await model.load()
        model.requestBiometrics(true)
        #expect(model.isAskingBiometricsPassword)
        #expect(!model.biometricsEnabled, "nothing changes before the password is confirmed")
        model.biometricsPassword = "wrong"
        await model.confirmBiometrics()
        #expect(model.biometricsError != nil)
        #expect(!model.biometricsEnabled)
        model.biometricsPassword = PreviewWalletServices.samplePassword
        await model.confirmBiometrics()
        #expect(model.biometricsEnabled)
        #expect(!model.isAskingBiometricsPassword)

        let unavailable = SecuritySettingsModel(vault: PreviewWalletServices.make(scenario: PreviewScenario(biometrics: .unavailable(reason: "")).instant()).vault)
        await unavailable.load()
        #expect(unavailable.biometricsUnavailableReason == "Touch ID is not available for Fearless on this Mac.")
        unavailable.requestBiometrics(true)
        #expect(!unavailable.isAskingBiometricsPassword)
    }

    @Test func walletsCanBeRenamedBackedUpAndDeleted() async throws {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.standard.instant())
        let changes = Box(0)
        let model = WalletsSettingsModel(services: services) { changes.value += 1 }
        await model.load()
        #expect(model.wallets.count == 3)
        #expect(model.selectedWallet?.id == PreviewSampleData.mainWalletID)

        #expect(!model.canRename)
        model.renameText = "  Everyday  "
        #expect(model.canRename)
        await model.rename()
        #expect(model.selectedWallet?.name == "Everyday")
        #expect(changes.value == 1)

        let savings = try #require(model.wallets.first { $0.id == PreviewSampleData.savingsWalletID })
        #expect(model.needsBackup(savings))
        await model.markBackedUp(savings)
        #expect(!model.needsBackup(try #require(model.wallets.first { $0.id == savings.id })))

        let watch = try #require(model.wallets.first { $0.isWatchOnly })
        #expect(!model.needsBackup(watch), "a watch-only wallet has nothing to back up")
        await model.delete(watch)
        #expect(model.wallets.count == 2)
        #expect(model.walletPendingDeletion == nil)
    }

    @Test func revealingAPhraseNeedsApprovalAndCanConfirmTheBackup() async throws {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.standard.instant())
        let model = WalletsSettingsModel(services: services) {}
        await model.load()
        let savings = try #require(model.wallets.first { $0.id == PreviewSampleData.savingsWalletID })
        model.begin(.revealPhrase(savings))
        await model.approve(with: .password("wrong"))
        #expect(model.revealedPhrase.isEmpty)
        #expect(model.approvalError == WalletError.wrongPassword.errorDescription)

        await model.approve(with: .password(PreviewWalletServices.samplePassword))
        #expect(model.revealedPhrase == PreviewWalletServices.samplePhrase(.words24))
        #expect(model.revealedDerivation == nil, "a wallet with standard settings needs only its words")
        #expect(!model.isPhraseVisible, "the phrase starts hidden")

        model.beginVerification()
        let verification = try #require(model.verification)
        for challenge in verification.challenges {
            verification.select(model.revealedPhrase[challenge.position], for: challenge.position)
        }
        await model.completeVerification()
        #expect(model.secretAction == nil)
        #expect(model.revealedPhrase.isEmpty, "the phrase is dropped when the sheet closes")
        #expect(try await services.wallets.wallets().first { $0.id == savings.id }?.isBackedUp == true)
    }

    @Test func aBackupShowsDerivationSettingsWhenTheWordsAreNotEnough() async throws {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.standard.instant())
        let model = WalletsSettingsModel(services: services) {}
        await model.load()
        let main = try #require(model.wallets.first { $0.id == PreviewSampleData.mainWalletID })
        model.begin(.revealPhrase(main))
        #expect(model.revealedDerivation == nil, "nothing is known before approval")
        await model.approve(with: .password(PreviewWalletServices.samplePassword))
        let derivation = try #require(model.revealedDerivation)
        #expect(derivation.substrateDerivationPath == "//polkadot///preview-only")
        #expect(derivation.evmDerivationPath == "m/44'/60'/0'/0/1")
        #expect(!model.isPhraseVisible, "paths follow the same reveal rule as the words: hidden first")
        model.finishSecretAction()
        #expect(model.revealedBackup == nil, "the paths are dropped with the words")
        #expect(model.revealedDerivation == nil)
    }

    @Test func exportingJSONNeedsAStrongFilePassword() async throws {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.standard.instant())
        let model = WalletsSettingsModel(services: services) {}
        await model.load()
        let main = try #require(model.wallets.first)
        model.begin(.exportJSON(main))
        #expect(model.exportEcosystem == .substrate)
        model.exportPassword = "short"
        model.exportPasswordConfirmation = "short"
        #expect(!model.canApprove)
        model.exportPassword = "File-Password-2026"
        model.exportPasswordConfirmation = "File-Password-2025"
        #expect(model.exportPasswordMismatch != nil)
        #expect(!model.canApprove)
        model.exportPasswordConfirmation = "File-Password-2026"
        #expect(model.canApprove)
        await model.approve(with: .password(PreviewWalletServices.samplePassword))
        #expect(model.exportedJSON != nil)
        #expect(model.exportFileName == "fearless-main-wallet-substrate.json")

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("fearless-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent(model.exportFileName)
        model.writeExport(to: url)
        let saved = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(saved?["address"] as? String == PreviewSampleData.alice.polkadot)
        #expect(model.secretAction == nil)
        #expect(model.exportPassword.isEmpty)
    }

    @Test func customNodesAreValidatedBeforeAndByTheEngine() async {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.standard.instant())
        let model = NodesModel(nodeService: services.nodes)
        await model.load(PreviewCatalog.polkadot)
        #expect(model.nodes.count == 3)
        #expect(model.selectedNodeID == nil, "automatic by default")

        model.beginAdd()
        model.newNodeURL = "rpc.example.org"
        #expect(model.urlProblem?.contains("wss://node.example.org") == true)
        #expect(!model.canAdd)
        model.newNodeURL = "https://rpc.example.org"
        #expect(model.urlProblem == "Polkadot nodes use wss:// or ws://.")
        model.newNodeURL = "wss://rpc.polkadot.io"
        #expect(model.urlProblem == "This node is already in the list.")

        model.newNodeURL = "wss://unreachable.example.org"
        #expect(model.canAdd)
        await model.addNode()
        #expect(model.addError != nil)
        #expect(model.isAddingNode, "the form stays open so the address can be corrected")
        #expect(model.newNodeURL == "wss://unreachable.example.org")

        model.newNodeName = "My node"
        model.newNodeURL = "wss://node.example.org"
        await model.addNode()
        #expect(!model.isAddingNode)
        #expect(model.nodes.count == 4)
        let custom = model.nodes.first { $0.isCustom }
        #expect(custom?.name == "My node")

        await model.select(custom?.id)
        #expect(model.selectedNodeID == custom?.id)
        if let custom { await model.remove(custom) }
        #expect(model.nodes.count == 3)
        #expect(model.selectedNodeID == nil, "removing the node in use returns to automatic")

        await model.load(PreviewCatalog.ethereum)
        model.beginAdd()
        model.newNodeURL = "https://rpc.example.org"
        #expect(model.urlProblem == nil, "EVM nodes may use https")
    }
}
