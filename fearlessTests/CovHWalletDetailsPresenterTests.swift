import XCTest
import SoraFoundation
import SSFModels
@testable import fearless

final class CovHWalletDetailsPresenterTests: XCTestCase {
    func testLoadSendsLocaleAndStartsInteractor() {
        let context = CovHWalletDetailsPresenterContext()
        XCTAssertEqual(context.view.locales.count, 1)
        XCTAssertEqual(context.interactor.calls, ["setup"])
        context.presenter.didTapCloseButton()
        context.presenter.didTapExportButton()
        XCTAssertEqual(context.wireframe.calls, ["dismiss"], "export is only offered in the export flow")
    }

    func testNormalFlowListsKeyAccessChainsAndSearches() {
        let context = CovHWalletDetailsPresenterContext()
        let enabled = CovHChainAccountFixture.chain(name: "Enabled")
        let disabled = CovHChainAccountFixture.chain(name: "Disabled", disabled: true)
        let storedDisabled = CovHChainAccountFixture.chain(name: "Stored", disabled: true)
        context.presenter.didReceive(storedChainAccounts: [CovHWalletDetailsFixture.storedAccount(for: storedDisabled)])
        context.presenter.didReceive(chains: [enabled, disabled, storedDisabled])
        XCTAssertEqual(context.factory.normalChains.last?.map(\.name), ["Enabled", "Stored"])
        XCTAssertEqual(context.factory.storedChains.last?.map(\.name), ["Stored"])

        context.presenter.searchTextDidChanged("sto")
        XCTAssertEqual(context.factory.searchTexts.last, "sto")
        context.presenter.applyLocalization()
        context.presenter.didReceive(updatedFlow: .normal(wallet: CovHChainAccountFixture.wallet()))
        XCTAssertEqual(context.view.states.count, 5)
        XCTAssertEqual(context.view.locales.count, 2)
        XCTAssertTrue(context.view.states.allSatisfy { if case .normal = $0 { return true } else { return false } })
    }

    func testExportFlowBuildsExportStateAndExportsEveryAccount() throws {
        let wallet = CovHChainAccountFixture.wallet()
        let chain = CovHChainAccountFixture.chain()
        let account = CovHWalletDetailsFixture.chainAccountResponse(for: chain, wallet: wallet, isChainAccount: false)
        let context = CovHWalletDetailsPresenterContext(flow: .export(wallet: wallet, accounts: [ChainAccountInfo(chain: chain, account: account)]))
        context.presenter.didReceive(chains: [chain])
        guard case .export = context.view.states.last else {
            return XCTFail("The export flow shows the export state")
        }
        XCTAssertEqual(context.factory.exportChains.last?.map(\.chainId), [chain.chainId])

        context.presenter.didTapExportButton()
        guard case let .multiple(exportWallet, accounts) = try XCTUnwrap(context.wireframe.exportFlows.first) else {
            return XCTFail("The export button exports the whole wallet")
        }
        XCTAssertEqual(exportWallet.metaId, wallet.metaId)
        XCTAssertEqual(accounts.map(\.chain.chainId), [chain.chainId])

        context.presenter.showActions(for: chain, account: account)
        XCTAssertEqual(context.interactor.exportRequests.map(\.chain.chainId), [chain.chainId])
    }

    func testErrorsFallBackToUndefinedWhenNotPresentable() {
        let context = CovHWalletDetailsPresenterContext()
        context.presenter.didReceive(error: NSError(domain: "first", code: 1))
        XCTAssertEqual(context.wireframe.errors.count, 1)
        context.wireframe.presentsErrors = false
        context.presenter.didReceive(error: NSError(domain: "second", code: 2))
        XCTAssertEqual(context.wireframe.errors.count, 3)
        guard case .undefined = context.wireframe.errors.last as? CommonError else {
            return XCTFail("An unpresentable error is replaced by the generic one")
        }
    }

    func testMissingAccountOffersOptionsAndSkipMarksChainUnused() throws {
        let chain = CovHChainAccountFixture.chain()
        let context = CovHWalletDetailsPresenterContext()
        context.presenter.showActions(for: chain, account: nil)
        XCTAssertEqual(context.wireframe.accountOptions.first, [.create, .import, .skip])
        try XCTUnwrap(context.wireframe.skipBlocks.first)(chain)
        XCTAssertEqual(context.interactor.unusedChains.map(\.chainId), [chain.chainId])

        let unused = CovHWalletDetailsPresenterContext(wallet: CovHChainAccountFixture.wallet().replacingUnusedChainIds([chain.chainId]))
        unused.presenter.showActions(for: chain, account: nil)
        XCTAssertEqual(unused.wireframe.accountOptions.first, [.create, .import])

        context.presenter.showActions(for: UniversalWalletRegistry.solanaMainnetChainModel, account: nil)
        XCTAssertEqual(context.wireframe.accountOptions.count, 1, "universal networks cannot be added by hand")
    }

    func testExistingAccountAsksInteractorForExportOptions() {
        let context = CovHWalletDetailsPresenterContext()
        let chain = CovHChainAccountFixture.chain()
        let account = CovHWalletDetailsFixture.chainAccountResponse(for: chain, wallet: context.wallet, isChainAccount: false)
        context.presenter.showActions(for: chain, account: account)
        XCTAssertEqual(context.interactor.exportRequests.map(\.account), [account])
        XCTAssertTrue(context.wireframe.calls.isEmpty)
    }

    func testActionsMenuRoutesExplorersReplaceAndAccountSwitches() throws {
        let context = CovHWalletDetailsPresenterContext()
        let chain = CovHWalletDetailsFixture.explorerChain()
        let stored = CovHWalletDetailsFixture.storedAccount(for: chain)
        let storedAddress = try XCTUnwrap(context.wallet.response(for: stored, request: chain.accountRequest())?.toAddress())
        let account = CovHWalletDetailsFixture.chainAccountResponse(for: chain, wallet: context.wallet, isChainAccount: true)
        let address = try XCTUnwrap(account.toAddress())
        context.presenter.didReceive(storedChainAccounts: [stored])
        context.presenter.didReceiveExportOptions(options: [.mnemonic], for: ChainAccountInfo(chain: chain, account: account))

        let items = try XCTUnwrap(context.wireframe.actionItems.first)
        XCTAssertEqual(items.map(CovHChainAccountFixture.actionName), [
            "copy", "switchNode", "export", "replace", "subscan", "polkascan", "etherscan", "reefscan", "oklink",
            "stored:\(storedAddress)", "walletAccount"
        ])
        let callback = try XCTUnwrap(context.wireframe.actionCallbacks.first)
        callback(1)
        callback(2)
        callback(3)
        let replace = try XCTUnwrap(context.wireframe.replaceCallbacks.first)
        replace(0)
        replace(1)
        (4 ... 8).forEach(callback)
        XCTAssertEqual(context.wireframe.calls, ["actions", "node", "export", "replace", "create", "import", "url", "url", "url", "url", "url"])
        XCTAssertEqual(context.wireframe.urls.first?.absoluteString, "https://scan.invalid/account/\(address)")
        XCTAssertEqual(context.wireframe.urls[2].absoluteString, "https://scan.invalid/address/\(address)")
        guard case let .single(exportChain, exportAddress, _) = try XCTUnwrap(context.wireframe.exportFlows.first) else {
            return XCTFail("A chain export covers that chain only")
        }
        XCTAssertEqual(exportChain.chainId, chain.chainId)
        XCTAssertEqual(exportAddress, address)

        callback(9)
        callback(10)
        XCTAssertEqual(context.wireframe.sheets.count, 2)
        XCTAssertTrue(context.wireframe.sheets.allSatisfy { $0.actions.count == 1 && $0.closeAction != nil })
        XCTAssertTrue(context.interactor.selections.isEmpty, "switching waits for confirmation")
        context.wireframe.sheets.forEach { $0.actions.first?.handler?() }
        XCTAssertEqual(context.interactor.selections, [
            .chainAccount(accountId: stored.accountId, publicKey: stored.publicKey),
            .walletAccount
        ])
    }

    func testUniversalAccountOffersPasswordSwitch() throws {
        let context = CovHWalletDetailsPresenterContext()
        let noPassword = UniversalWalletNoPasswordAccount(slot: .solana, oldAddress: "old", newAddress: "new", newPublicKey: Data([1]))
        context.presenter.didReceive(noPasswordAccounts: [noPassword])
        context.presenter.showActions(
            for: UniversalWalletRegistry.solanaMainnetChainModel,
            account: CovHWalletDetailsFixture.solanaResponse(wallet: context.wallet)
        )
        XCTAssertTrue(context.interactor.exportRequests.isEmpty)
        let items = try XCTUnwrap(context.wireframe.actionItems.first)
        XCTAssertEqual(items.first.map(CovHChainAccountFixture.actionName), "copy")
        XCTAssertEqual(items.last.map(CovHChainAccountFixture.actionName), "passwordAccount")
        XCTAssertFalse(items.map(CovHChainAccountFixture.actionName).contains("export"))
        try XCTUnwrap(context.wireframe.actionCallbacks.first)(items.count - 1)
        XCTAssertEqual(context.interactor.switches, [noPassword])
    }

    func testSwitchOutcomesArePresentedAsANotice() {
        let context = CovHWalletDetailsPresenterContext()
        let account = UniversalWalletNoPasswordAccount(slot: .ton, oldAddress: "old", newAddress: "new", newPublicKey: Data([2]))
        context.presenter.didReceive(switchOutcomes: [.ton: .stillFunded], for: [account])
        XCTAssertEqual(context.wireframe.sheets.count, 1)
        XCTAssertFalse(context.wireframe.sheets.first?.title.isEmpty ?? true)
    }

    func testBaseActionsDependOnChainKind() {
        XCTAssertEqual(
            WalletDetailsPresenter.baseActions(for: CovHChainAccountFixture.chain()).map(CovHChainAccountFixture.actionName),
            ["copy", "switchNode", "export", "replace"]
        )
        XCTAssertEqual(
            WalletDetailsPresenter.baseActions(for: UniversalWalletRegistry.solanaMainnetChainModel).map(CovHChainAccountFixture.actionName),
            ["copy"]
        )
    }
}
