import XCTest
import UIKit
import SSFModels
@testable import fearless

final class CovHWalletMainContainerTests: XCTestCase {
    func testLoadAndWalletReplacementPublishModelsAndBalanceContext() {
        let fixture = CovHWalletMainFixture()
        fixture.start()
        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
        let replacement = AccountGenerator.generateMetaAccount()
        fixture.presenter.didReceiveAccount(replacement)
        fixture.presenter.applyLocalization()
        drain { fixture.view.models.count == 4 }
        XCTAssertEqual(fixture.view.models.map(\.walletName), [fixture.wallet.name, fixture.wallet.name, replacement.name, replacement.name])
        guard case let .networkManagement(wallet) = fixture.modules.balanceTypes.first else {
            return XCTFail("Expected the new wallet balance context")
        }
        XCTAssertEqual(wallet.metaId, replacement.metaId)
    }

    func testNetworkFiltersUpdateAssetAndNftModulesAndIgnoreMissingChain() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start()
        let chains = ChainModelGenerator.generate(count: 2)
        let chain = try XCTUnwrap(chains.first)
        fixture.presenter.didReceiveSelected(tuple: (.all, chains))
        XCTAssertEqual(fixture.modules.filters.last, [])
        XCTAssertEqual(fixture.factory.chains.last?.map(\.chainId), chains.map(\.chainId))
        fixture.presenter.didReceiveSelected(tuple: (.chain(chain.chainId), chains))
        XCTAssertEqual(fixture.modules.filters.last, [.chainId(chain.chainId)])
        XCTAssertEqual(fixture.factory.chains.last?.map(\.chainId), [chain.chainId])
        fixture.presenter.didReceiveSelected(tuple: (.popular, chains))
        XCTAssertEqual(fixture.modules.filters.last, [.chainIds([])])
        fixture.presenter.didReceiveSelected(tuple: (.favourite, chains))
        XCTAssertEqual(fixture.modules.filters.last, [.chainIds([])])
        XCTAssertEqual(fixture.modules.chains.count, 4)
        fixture.presenter.didReceiveSelected(tuple: (.chain("missing"), chains))
        XCTAssertEqual(fixture.modules.chains.count, 4)
        XCTAssertEqual(fixture.factory.filters.count, 6)
    }

    func testNavigationUsesSelectedWalletAndForwardsHomeActions() {
        let fixture = CovHWalletMainFixture()
        fixture.start()
        fixture.presenter.didTapOnSwitchWallet()
        fixture.presenter.didTapOnQR()
        fixture.presenter.didTapSearch()
        fixture.presenter.didTapSelectNetwork()
        fixture.presenter.didTapOnBalance()
        WalletHomeAction.allCases.forEach(fixture.presenter.didTapHomeAction)
        fixture.presenter.showAddNewWallet()
        fixture.presenter.showImportWallet(defaultSource: .mnemonic)
        fixture.presenter.showImportGoogle()
        fixture.presenter.showGetPreinstalledWallet()
        fixture.presenter.addressDidCopied()
        XCTAssertEqual(fixture.router.calls, ["wallets", "qr", "search", "network", "currency",
                                               "picker", "picker", "picker", "swap", "create", "import", "backup", "preinstalled"])
        XCTAssertEqual(fixture.router.actions, [.send, .receive, .buy])
        XCTAssertTrue(fixture.router.wallets.allSatisfy { $0.metaId == fixture.wallet.metaId })
        XCTAssertEqual(fixture.router.statusCount, 1)
    }

    func testAssetSelectionRoutesAfterDismissalAndRejectsInvalidContexts() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start()
        let chain = try XCTUnwrap(ChainModelGenerator.generate(count: 1).first)
        let asset = ChainAsset(chain: chain, asset: ChainModelGenerator.generateAssetWithId("asset", symbol: "AST", assetPresicion: 12))
        fixture.presenter.assetSelection(didCompleteWith: nil, contextTag: 1)
        fixture.presenter.assetSelection(didCompleteWith: asset, contextTag: nil)
        fixture.presenter.assetSelection(didCompleteWith: asset, contextTag: 100)
        XCTAssertTrue(fixture.router.calls.isEmpty)
        WalletHomeAction.allCases.forEach { fixture.presenter.assetSelection(didCompleteWith: asset, contextTag: $0.rawValue) }
        XCTAssertTrue(fixture.router.calls.isEmpty)
        drain { fixture.router.calls.count == 3 }
        XCTAssertEqual(fixture.router.calls, ["send", "receive", "asset"])
        XCTAssertEqual(fixture.router.assets.map(\.asset.id), ["asset", "asset"])
    }

    func testSyncAvailabilityAndErrorsAreForwarded() {
        let fixture = CovHWalletMainFixture()
        fixture.start()
        fixture.presenter.didReceive(syncUpdate: .catalog(running: true))
        fixture.presenter.didReceive(syncUpdate: .catalogFailed)
        fixture.presenter.didReceiveNftAvailability(isNftAvailable: true)
        fixture.presenter.didReceiveNftAvailability(isNftAvailable: false)
        fixture.presenter.didReceiveError(NSError(domain: "coverage", code: 42))
        XCTAssertEqual(fixture.view.sync, [.catalog(running: true), .catalogFailed])
        XCTAssertEqual(fixture.view.availability, [true, false])
        XCTAssertEqual((fixture.router.errors.first as NSError?)?.code, 42)
    }

    func testWalletConnectSuccessAndFailure() {
        let fixture = CovHWalletMainFixture()
        fixture.start()
        fixture.presenter.didFinishWith(scanType: .walletConnect("wc:success"))
        drain { fixture.interactor.uris.count == 1 }
        XCTAssertEqual(fixture.interactor.uris, ["wc:success"])
        XCTAssertTrue(fixture.router.errors.isEmpty)
        fixture.interactor.error = NSError(domain: "connect", code: 7)
        fixture.presenter.didFinishWith(scanType: .walletConnect("wc:failure"))
        drain { fixture.router.errors.count == 1 }
        XCTAssertEqual(fixture.interactor.uris, ["wc:success", "wc:failure"])
        XCTAssertEqual((fixture.router.errors.first as NSError?)?.code, 7)
    }

    func testStashNoticeImportAction() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start()
        fixture.presenter.didReceiveStashAccountIssue(address: "stash-address")
        let sheet = try XCTUnwrap(fixture.router.sheets.last)
        XCTAssertTrue(sheet.message?.contains("stash-address") == true)
        XCTAssertEqual(sheet.actions.count, 1)
        sheet.actions.first?.handler?()
        XCTAssertEqual(fixture.router.calls, ["import"])
    }

    func testControllerNoticeRoutesAccordingToStashAvailability() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start()
        let chain = try XCTUnwrap(ChainModelGenerator.generate(count: 1).first)
        let asset = ChainAsset(chain: chain, asset: ChainModelGenerator.generateAssetWithId("asset", symbol: "AST"))
        let issue = ControllerAccountIssue(chainAsset: asset, wallet: fixture.wallet, address: "controller")
        for hasStash in [true, false] {
            fixture.presenter.didReceiveControllerAccountIssue(issue: issue, hasStashItem: hasStash)
            let sheet = try XCTUnwrap(fixture.router.sheets.last)
            XCTAssertTrue(sheet.message?.contains(chain.name) == true)
            sheet.actions.first?.handler?()
        }
        drain { fixture.router.calls.count == 2 }
        XCTAssertEqual(fixture.router.calls, ["controller", "staking"])
        XCTAssertEqual(fixture.router.assets.first?.chain.chainId, chain.chainId)
    }

    func testStoredRecordNoticesAcknowledgeOnlyOnDismissalAndAdvance() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start(hosted: true)
        let first = StoredWalletRecordsNotice.recordsNotShown(wallets: 2, chainAccounts: 3)
        let second = StoredWalletRecordsNotice.storedChainAccounts(walletIds: ["other"], walletNames: ["Other wallet"])
        fixture.presenter.didReceiveStoredWalletRecordsNotices([first, second])
        XCTAssertTrue(fixture.interactor.notices.isEmpty)
        let sheet = try XCTUnwrap(fixture.router.sheets.first)
        XCTAssertEqual(sheet.actions.count, 2)
        XCTAssertFalse(sheet.message?.isEmpty ?? true)
        sheet.dismissCompletion?()
        XCTAssertEqual(fixture.interactor.notices, [first])
        let next = try XCTUnwrap(fixture.router.sheets.last)
        XCTAssertTrue(next.actions.isEmpty)
        XCTAssertTrue(next.message?.contains("Other wallet") == true)
        next.dismissCompletion?()
        XCTAssertEqual(fixture.interactor.notices, [first, second])
        XCTAssertEqual(fixture.router.sheets.count, 2)
    }

    func testStoredRecordActionDefersImportUntilDismissal() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start(hosted: true)
        fixture.presenter.didReceiveStoredWalletRecordsNotices([.recordsNotShown(wallets: 1, chainAccounts: 0)])
        let sheet = try XCTUnwrap(fixture.router.sheets.last)
        sheet.actions.first?.handler?()
        XCTAssertTrue(fixture.router.calls.isEmpty)
        sheet.dismissCompletion?()
        XCTAssertEqual(fixture.router.calls, ["import"])
        XCTAssertEqual(fixture.interactor.notices.count, 1)
    }

    func testStoredChainAccountsOfferDetailsForCurrentWallet() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start(hosted: true)
        fixture.presenter.didReceiveStoredWalletRecordsNotices([
            .storedChainAccounts(walletIds: [fixture.wallet.metaId], walletNames: [fixture.wallet.name])
        ])
        let sheet = try XCTUnwrap(fixture.router.sheets.last)
        XCTAssertEqual(sheet.actions.count, 1)
        sheet.actions.first?.handler?()
        XCTAssertTrue(fixture.router.calls.isEmpty)
        sheet.dismissCompletion?()
        XCTAssertEqual(fixture.router.calls, ["details"])
        XCTAssertEqual(fixture.router.wallets.last?.metaId, fixture.wallet.metaId)
    }

    func testUpdateSecurityNoticePrecedesStoredRecordsAndAcknowledgesOnClose() throws {
        let fixture = CovHWalletMainFixture()
        fixture.notice.isPending = true
        fixture.start(hosted: true)
        let sheet = try XCTUnwrap(fixture.router.sheets.first)
        XCTAssertFalse(sheet.showsCloseButton)
        fixture.presenter.didReceiveStoredWalletRecordsNotices([.recordsNotShown(wallets: 1, chainAccounts: 0)])
        XCTAssertEqual(fixture.router.sheets.count, 1)
        XCTAssertEqual(fixture.notice.acknowledgements, 0)
        sheet.dismissCompletion?()
        XCTAssertEqual(fixture.notice.acknowledgements, 1)
        XCTAssertEqual(fixture.router.sheets.count, 2)
    }

    func testPasswordSwitchWaitsForDismissalThenOutcomesBeforeArrivals() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start(hosted: true)
        let account = UniversalWalletNoPasswordAccount(slot: .solana, oldAddress: "old-sol", newAddress: "new-sol", newPublicKey: Data([1]))
        fixture.presenter.didReceiveUniversalWalletNoPasswordAccounts([account])
        let sheet = try XCTUnwrap(fixture.router.sheets.last)
        XCTAssertTrue(sheet.message?.contains("new-sol") == true)
        XCTAssertEqual(sheet.actions.count, 2)
        sheet.actions.first?.handler?()
        XCTAssertTrue(fixture.interactor.switches.isEmpty)
        sheet.dismissCompletion?()
        XCTAssertEqual(fixture.interactor.switches, [[account]])
        XCTAssertEqual(fixture.interactor.passwordAcknowledgements, 1)
        let arrival = UniversalWalletOldAddressArrival(slot: .solana, oldAddress: "old-sol", balance: "3 SOL", walletId: fixture.wallet.metaId)
        fixture.presenter.didReceiveUniversalWalletOldAddressArrivals([arrival])
        XCTAssertEqual(fixture.router.sheets.count, 1)
        fixture.presenter.didReceiveUniversalWalletSwitchOutcomes([.solana: .switched], for: [account])
        XCTAssertEqual(fixture.router.sheets.count, 2)
        fixture.router.sheets.last?.dismissCompletion?()
        XCTAssertEqual(fixture.router.sheets.count, 3)
        XCTAssertTrue(fixture.router.sheets.last?.message?.contains("3 SOL") == true)
        fixture.router.sheets.last?.dismissCompletion?()
        XCTAssertEqual(fixture.interactor.arrivals, [[arrival]])
    }

    func testPasswordNoticeDismissalWithoutSwitchAcknowledgesAndStops() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start(hosted: true)
        let account = UniversalWalletNoPasswordAccount(slot: .ton, oldAddress: "old-ton", newAddress: "new-ton", newPublicKey: Data([2]))
        fixture.presenter.didReceiveUniversalWalletNoPasswordAccounts([account])
        let sheet = try XCTUnwrap(fixture.router.sheets.last)
        sheet.dismissCompletion?()
        XCTAssertEqual(fixture.interactor.passwordAcknowledgements, 1)
        XCTAssertTrue(fixture.interactor.switches.isEmpty)
        XCTAssertEqual(fixture.router.sheets.count, 1)
    }

    func testUnhostedNoticesRemainUnacknowledgedAfterRetries() {
        let fixture = CovHWalletMainFixture()
        fixture.notice.isPending = true
        fixture.start()
        fixture.presenter.didReceiveStoredWalletRecordsNotices([.recordsNotShown(wallets: 1, chainAccounts: 0)])
        drain(timeout: 6.5) { !fixture.router.sheets.isEmpty }
        XCTAssertTrue(fixture.router.sheets.isEmpty)
        XCTAssertTrue(fixture.interactor.notices.isEmpty)
        XCTAssertEqual(fixture.notice.acknowledgements, 0)
    }

    private func drain(timeout: TimeInterval = 3, until predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}
