import AppKit
import DesignSystem
import Foundation
import Testing
import WalletCore
@testable import WalletPreviewSupport
@testable import WalletUI

@MainActor
@Suite("Auto-lock")
struct AutoLockTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func idlePolicyLocksAtTheConfiguredTime() {
        let policy = AutoLockPolicy(idleMinutes: 5, lockOnSleep: true, lockOnScreenLock: true)
        #expect(!policy.shouldLock(lastActivity: start, now: start.addingTimeInterval(299)))
        #expect(policy.shouldLock(lastActivity: start, now: start.addingTimeInterval(300)))
        #expect(policy.secondsUntilLock(lastActivity: start, now: start.addingTimeInterval(60)) == 240)
        #expect(policy.secondsUntilLock(lastActivity: start, now: start.addingTimeInterval(900)) == 0)
    }

    @Test func neverMeansNever() {
        let policy = AutoLockPolicy(idleMinutes: 0, lockOnSleep: false, lockOnScreenLock: false)
        #expect(!policy.shouldLock(lastActivity: start, now: start.addingTimeInterval(1_000_000)))
        #expect(policy.secondsUntilLock(lastActivity: start, now: start) == nil)
        #expect(!policy.shouldLock(on: .systemWillSleep))
        #expect(!policy.shouldLock(on: .screenLocked))
    }

    @Test func eventsFollowTheirOwnSwitches() {
        let sleepOnly = AutoLockPolicy(idleMinutes: 5, lockOnSleep: true, lockOnScreenLock: false)
        #expect(sleepOnly.shouldLock(on: .systemWillSleep))
        #expect(!sleepOnly.shouldLock(on: .screenLocked))
    }

    @Test func controllerLocksAfterIdleAndActivityRestartsTheClock() {
        let now = Box(start)
        let locks = Box(0)
        let unlocked = Box(true)
        let controller = AutoLockController(
            policy: { AutoLockPolicy(idleMinutes: 1, lockOnSleep: true, lockOnScreenLock: true) },
            isUnlocked: { unlocked.value },
            lock: { locks.value += 1 },
            now: { now.value }
        )
        now.value = start.addingTimeInterval(59)
        controller.tick()
        #expect(locks.value == 0)

        controller.noteActivity()
        now.value = start.addingTimeInterval(59 + 59)
        controller.tick()
        #expect(locks.value == 0, "activity restarted the idle clock")

        now.value = start.addingTimeInterval(59 + 60)
        controller.tick()
        #expect(locks.value == 1)
    }

    @Test func controllerIgnoresEverythingWhileLocked() {
        let now = Box(start)
        let locks = Box(0)
        let unlocked = Box(false)
        let controller = AutoLockController(
            policy: { AutoLockPolicy(idleMinutes: 1, lockOnSleep: true, lockOnScreenLock: true) },
            isUnlocked: { unlocked.value },
            lock: { locks.value += 1 },
            now: { now.value }
        )
        now.value = start.addingTimeInterval(3_600)
        controller.tick()
        controller.handle(.systemWillSleep)
        controller.handle(.screenLocked)
        #expect(locks.value == 0)

        // Unlocking later starts counting from then, not from an hour ago.
        unlocked.value = true
        controller.tick()
        #expect(locks.value == 0)
        controller.handle(.screenLocked)
        #expect(locks.value == 1)
    }

    @Test func settingsFeedThePolicy() {
        let settings = makeSettings()
        #expect(settings.autoLockPolicy == AutoLockPolicy(idleMinutes: 5, lockOnSleep: true, lockOnScreenLock: true), "defaults")
        settings.autoLockMinutes = 30
        settings.lockOnSleep = false
        #expect(settings.autoLockPolicy == AutoLockPolicy(idleMinutes: 30, lockOnSleep: false, lockOnScreenLock: true))
        settings.autoLockMinutes = -4
        #expect(settings.autoLockMinutes == 0)
    }
}

@MainActor
@Suite("App model")
struct AppModelTests {
    private func startedApp(_ scenario: PreviewScenario = .standard) async -> AppModel {
        let app = AppModel(services: PreviewWalletServices.make(scenario: scenario.instant()), settings: makeSettings())
        app.start(monitorSystem: false)
        return app
    }

    private func unlockedApp() async throws -> AppModel {
        let app = await startedApp()
        #expect(await waitUntil { app.route == .main && app.portfolio.lastUpdated != nil && app.activity.state == .loaded })
        return app
    }

    @Test func routesFollowTheVault() async {
        let firstRun = await startedApp(.firstRun)
        #expect(firstRun.route == .launching)
        #expect(await waitUntil { firstRun.route == .onboarding })
        #expect(firstRun.onboarding?.mode == .firstRun)

        let locked = await startedApp(.locked)
        #expect(await waitUntil { locked.route == .locked })
        #expect(locked.wallets.isEmpty, "nothing is loaded while locked")

        let empty = await startedApp(.emptyWalletList)
        #expect(await waitUntil { empty.route == .onboarding })
        #expect(empty.onboarding?.mode == .firstWallet)
    }

    @Test func unlockingLoadsWalletsAndData() async throws {
        let app = await startedApp(.locked)
        #expect(await waitUntil { app.route == .locked })
        app.lockModel.password = PreviewWalletServices.samplePassword
        await app.lockModel.unlockWithPassword()
        #expect(await waitUntil { app.route == .main && app.portfolio.lastUpdated != nil })
        #expect(app.wallets.count == 3)
        #expect(app.selectedWallet?.id == PreviewSampleData.mainWalletID)
        #expect(app.summary.total > 17_000)
        #expect(app.totalValueText == Money.fiat(app.summary.total, currency: .usd))
        #expect(app.walletsNeedingBackup == 1)
    }

    @Test func lockingDropsEverythingSensitive() async throws {
        let app = try await unlockedApp()
        app.searchText = "dot"
        app.section = .assets
        app.selectedAssetID = PreviewCatalog.dot.id
        app.presentSend()
        guard case .send(let send) = app.sheet else {
            Issue.record("the send sheet should be open")
            return
        }
        send.recipientText = PreviewSampleData.sampleRecipientPolkadot
        send.approvalPassword = "typed but not sent"

        app.lock()
        #expect(app.sheet == nil)
        #expect(app.wallets.isEmpty)
        #expect(app.selectedWallet == nil)
        #expect(app.portfolio.balances.isEmpty)
        #expect(app.activity.items.isEmpty)
        #expect(app.searchText.isEmpty)
        #expect(app.selectedAssetID == nil)
        #expect(send.approvalPassword.isEmpty)
        #expect(app.totalValueText == "—", "no amount is shown once locked")
        #expect(await waitUntil { app.route == .locked })
        #expect(app.lockModel.password.isEmpty)
    }

    @Test func privacyModeMasksTheTotal() async throws {
        let app = try await unlockedApp()
        let visible = app.totalValueText
        #expect(visible == Money.fiat(app.summary.total, currency: .usd))
        app.toggleBalancesHidden()
        #expect(app.totalValueText == Money.mask)
        #expect(app.settings.balancesHidden)
        app.toggleBalancesHidden()
        #expect(app.totalValueText == visible)
    }

    @Test func switchingWalletsReloadsAndRemembersTheChoice() async throws {
        let app = try await unlockedApp()
        await app.selectWallet(at: 2)
        #expect(app.selectedWallet?.id == PreviewSampleData.savingsWalletID)
        #expect(app.settings.selectedWalletID == PreviewSampleData.savingsWalletID.description)
        #expect(app.portfolio.walletID == PreviewSampleData.savingsWalletID)
        #expect(app.activity.items.count == 3)
        #expect(app.needsBackup(try #require(app.selectedWallet)))
        await app.selectWallet(at: 9)
        #expect(app.selectedWallet?.id == PreviewSampleData.savingsWalletID, "an empty slot changes nothing")
    }

    @Test func sheetsOpenForTheSelectedWallet() async throws {
        let app = try await unlockedApp()
        app.presentReceive(chainID: PreviewCatalog.ethereum.id)
        guard case .receive(let receive) = app.sheet else {
            Issue.record("the receive sheet should be open")
            return
        }
        #expect(receive.chain?.id == PreviewCatalog.ethereum.id)
        #expect(!receive.chains.contains { $0.isTestnet })
        app.dismissSheet()
        #expect(app.sheet == nil)

        app.presentSend(assetID: PreviewCatalog.eth.id)
        guard case .send(let send) = app.sheet else {
            Issue.record("the send sheet should be open")
            return
        }
        #expect(send.assetID == PreviewCatalog.eth.id)
        app.dismissSheet()

        await app.selectWallet(PreviewSampleData.watchWalletID)
        app.presentSend()
        #expect(app.sheet == nil, "a watch-only wallet cannot open Send")
        #expect(app.toast?.text == "Watch-only wallets cannot send.")
    }

    @Test func addingAWalletSelectsIt() async throws {
        let app = try await unlockedApp()
        app.presentAddWallet(creating: false)
        guard case .addWallet(let model) = app.sheet else {
            Issue.record("the add wallet sheet should be open")
            return
        }
        #expect(model.step == .welcome)
        await model.choose(.watchOnly)
        model.watchEVMAddress = "0x00000000000000000000000000000000000000AA"
        await model.continueImport()
        model.walletName = "Cold storage"
        await model.finish()
        #expect(await waitUntil { app.wallets.count == 4 && app.selectedWallet?.name == "Cold storage" })
        #expect(app.sheet == nil)
    }

    @Test func hidingAnAssetRemovesItFromTotals() async throws {
        let app = try await unlockedApp()
        let before = app.summary.total
        app.selectedAssetID = PreviewCatalog.eth.id
        app.hideAsset(PreviewCatalog.eth.id)
        #expect(app.selectedAssetID == nil)
        #expect(app.settings.isHidden(PreviewCatalog.eth.id))
        #expect(app.summary.total < before)
        #expect(!app.portfolioRows.contains { $0.id == PreviewCatalog.eth.id })
    }

    @Test func copyAddressUsesTheSelectedAssetsNetwork() async throws {
        // A private pasteboard, so the test never touches the user's clipboard.
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let app = AppModel(
            services: PreviewWalletServices.make(scenario: PreviewScenario.standard.instant()),
            settings: makeSettings(),
            clipboard: Clipboard(pasteboard: pasteboard)
        )
        app.start(monitorSystem: false)
        #expect(await waitUntil { app.route == .main && app.portfolio.lastUpdated != nil })
        app.section = .assets
        app.selectedAssetID = PreviewCatalog.eth.id
        await app.copyAddress()
        #expect(pasteboard.string(forType: .string) == PreviewSampleData.evmAccount0)
        #expect(app.toast?.text == "Ethereum address copied")
        app.section = .portfolio
        await app.copyAddress()
        #expect(pasteboard.string(forType: .string) == PreviewSampleData.alice.polkadot)
    }

    @Test func lockingClearsACopiedPhrase() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let clipboard = Clipboard(pasteboard: pasteboard)
        let app = AppModel(
            services: PreviewWalletServices.make(scenario: PreviewScenario.standard.instant()),
            settings: makeSettings(),
            clipboard: clipboard
        )
        app.start(monitorSystem: false)
        #expect(await waitUntil { app.route == .main && app.portfolio.lastUpdated != nil })
        clipboard.copyConcealed("twelve secret words", clearAfter: 60)
        app.lock()
        #expect(pasteboard.string(forType: .string) == nil)
    }

    @Test func erasingReturnsToFirstLaunch() async throws {
        let app = try await unlockedApp()
        app.settings.setHidden(true, assetID: PreviewCatalog.eth.id)
        app.securitySettings.beginErase()
        app.securitySettings.eraseConfirmation = "erase"
        #expect(!app.securitySettings.canErase, "the word must be typed exactly")
        app.securitySettings.eraseConfirmation = LockModel.eraseConfirmationWord
        await app.securitySettings.eraseAll()
        #expect(await waitUntil { app.route == .onboarding && app.onboarding?.mode == .firstRun })
        #expect(app.wallets.isEmpty)
        #expect(app.settings.hiddenAssetKeys.isEmpty)
        #expect(app.settings.selectedWalletID == nil)
    }
}

@MainActor
@Suite("Lock screen")
struct LockTests {
    private func makeModel() -> (LockModel, WalletServices) {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.locked.instant())
        return (LockModel(vault: services.vault), services)
    }

    @Test func aWrongPasswordIsReportedAndCounted() async {
        let (model, services) = makeModel()
        #expect(!model.canUnlock)
        model.password = "wrong"
        await model.unlockWithPassword()
        #expect(model.failedAttempts == 1)
        #expect(model.errorMessage == WalletError.wrongPassword.errorDescription)
        #expect(model.password.isEmpty)
        #expect(await services.vault.state() == .locked)
    }

    @Test func theRightPasswordUnlocks() async {
        let (model, services) = makeModel()
        model.password = PreviewWalletServices.samplePassword
        await model.unlockWithPassword()
        #expect(await services.vault.state() == .unlocked)
        #expect(model.errorMessage == nil)
        #expect(model.password.isEmpty)
    }

    @Test func touchIDIsOfferedOnlyWhenEnabled() async {
        let (model, services) = makeModel()
        await model.load()
        #expect(model.canUseBiometrics)
        await model.unlockWithBiometrics()
        #expect(await services.vault.state() == .unlocked)

        let plain = LockModel(vault: PreviewWalletServices.make(scenario: PreviewScenario(vault: .locked).instant()).vault)
        await plain.load()
        #expect(!plain.canUseBiometrics)
    }

    @Test func erasingNeedsTheTypedWord() async {
        let (model, services) = makeModel()
        model.beginErase()
        #expect(model.isShowingErase)
        model.eraseConfirmation = "Erase"
        #expect(!model.canErase)
        await model.eraseAll()
        #expect(await services.vault.state() == .locked)
        model.eraseConfirmation = "ERASE"
        #expect(model.canErase)
        await model.eraseAll()
        #expect(await services.vault.state() == .uninitialized)
        #expect(!model.isShowingErase)
    }
}
