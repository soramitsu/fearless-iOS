import XCTest
import BigInt
import SoraFoundation
import SSFModels
@testable import fearless

final class CovHChainAccountPresenterContext {
    let view = CovHChainAccountViewSpy()
    let interactor: CovHChainAccountInteractorSpy
    let wireframe = CovHChainAccountWireframeSpy()
    let factory = CovHChainAccountFactoryStub()
    let balanceModule = CovHChainAccountBalanceModuleSpy()
    let output = CovHChainAccountModuleOutputSpy()
    let wallet: MetaAccountModel
    let presenter: ChainAccountPresenter

    init(chainAsset: ChainAsset, wallet: MetaAccountModel = CovHChainAccountFixture.wallet(), mode: ChainAccountViewMode = .extended) {
        interactor = CovHChainAccountInteractorSpy(chainAsset: chainAsset)
        self.wallet = wallet
        presenter = ChainAccountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: factory,
            logger: Logger.shared,
            wallet: wallet,
            moduleOutput: output,
            balanceInfoModule: balanceModule,
            localizationManager: LocalizationManager.shared,
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet),
            mode: mode
        )
        presenter.view = view
        // Setting the localization manager in init already queued one view model for the view.
        CovHChainAccountFixture.spin(timeout: 1) { !view.states.isEmpty }
        view.states.removeAll()
        factory.wallets.removeAll()
        factory.chainAssets.removeAll()
        factory.modes.removeAll()
    }

    var address: String? {
        wallet.fetch(for: interactor.chainAsset.chain.accountRequest())?.toAddress()
    }
}

final class CovHChainAccountPresenterTests: XCTestCase {
    func testSetupStartsInteractorAndPublishesLoadedState() {
        let context = CovHChainAccountPresenterContext(chainAsset: CovHChainAccountFixture.chainAsset())
        context.presenter.setup()
        XCTAssertEqual(context.interactor.calls, ["setup"])
        CovHChainAccountFixture.spin { !context.view.states.isEmpty }
        XCTAssertEqual(context.view.loadedModels.map(\.walletName), [context.wallet.name])
        XCTAssertEqual(context.factory.modes, [.extended])

        context.presenter.applyLocalization()
        CovHChainAccountFixture.spin { context.view.states.count == 2 }
        XCTAssertEqual(context.view.loadedModels.count, 2)
    }

    func testBalanceViewModelWaitsForEveryInputAndSumsLocks() throws {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let context = CovHChainAccountPresenterContext(chainAsset: chainAsset)
        let info = AccountInfo(
            nonce: 0, consumers: 0, providers: 1,
            data: AccountData(free: BigUInt(5_000_000_000_000), reserved: .zero, frozen: .zero)
        )
        context.presenter.didReceive(accountInfo: info, for: chainAsset, accountId: Data(repeating: 1, count: 32))
        context.presenter.didReceiveAssetFrozen(1)
        context.presenter.didReceiveBalanceLocks(2)
        CovHChainAccountFixture.spin { context.view.balances.count == 3 }
        XCTAssertEqual(context.view.balances.count, 3)
        XCTAssertTrue(context.view.balances.allSatisfy { $0 == nil }, "no wallet balance yet")
        XCTAssertTrue(context.balanceModule.infoTypes.isEmpty)

        context.presenter.didReceiveWalletBalancesResult(.success([:]))
        CovHChainAccountFixture.spin { context.view.balances.count == 4 }
        let balance = try XCTUnwrap(context.view.balances.last ?? nil)
        XCTAssertTrue(balance.hasLockedTokens)
        XCTAssertNil(balance.lockedTitle)
        let locale = Locale(identifier: "en")
        XCTAssertTrue(balance.transferrableValue.value(for: locale).amount.contains("4"))
        XCTAssertTrue(balance.lockedValue.value(for: locale).amount.contains("3"))
    }

    func testBalanceErrorsStillProduceAViewModelWithoutLocks() throws {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let context = CovHChainAccountPresenterContext(chainAsset: chainAsset)
        context.presenter.didReceive(accountInfo: nil, for: chainAsset, accountId: Data(repeating: 1, count: 32))
        context.presenter.didReceiveAssetFrozenError(NSError(domain: "frozen", code: 1))
        context.presenter.didReceiveBalanceLocksError(NSError(domain: "locks", code: 2))
        context.presenter.didReceiveWalletBalancesResult(.failure(NSError(domain: "balances", code: 3)))
        context.presenter.didReceiveMinimumBalance(result: .success(BigUInt(1)))
        context.presenter.didReceiveMinimumBalance(result: .failure(NSError(domain: "minimum", code: 4)))
        CovHChainAccountFixture.spin { context.view.balances.count == 4 }
        XCTAssertEqual(context.view.balances.count, 4)
        let balance = try XCTUnwrap(context.view.balances.last ?? nil)
        XCTAssertFalse(balance.hasLockedTokens)
        XCTAssertTrue(balance.transferrableValue.value(for: Locale(identifier: "en")).amount.contains("0"))
    }

    func testBitcoinBalanceShowsPendingConfirmationRowWithoutWalletBalance() throws {
        let chainAsset = try CovHChainAccountFixture.bitcoinChainAsset()
        let context = CovHChainAccountPresenterContext(chainAsset: chainAsset)
        let info = AccountInfo(nonce: 0, consumers: 0, providers: 1, data: AccountData(free: 300_000, reserved: .zero, frozen: 100_000))
        context.presenter.didReceiveAssetFrozen(.zero)
        context.presenter.didReceiveBalanceLocks(.zero)
        context.presenter.didReceive(accountInfo: info, for: chainAsset, accountId: Data(repeating: 1, count: 32))
        CovHChainAccountFixture.spin { context.view.balances.count == 3 }
        let balance = try XCTUnwrap(context.view.balances.last ?? nil)
        XCTAssertFalse(balance.hasLockedTokens)
        XCTAssertEqual(balance.lockedTitle?.value(for: Locale(identifier: "en")), "Pending confirmation")
        guard case let .chainAsset(_, replaced) = context.balanceModule.infoTypes.last else {
            return XCTFail("A universal chain account refreshes the balance module")
        }
        XCTAssertEqual(replaced.chain.chainId, chainAsset.chain.chainId)
    }

    func testSimpleButtonsRouteThroughWireframe() {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let context = CovHChainAccountPresenterContext(chainAsset: chainAsset)
        context.presenter.didTapBackButton()
        context.presenter.didTapSendButton()
        context.presenter.didTapReceiveButton()
        context.presenter.didTapCrossChainButton()
        context.presenter.didTapPolkaswapButton()
        context.presenter.didTapLockedInfoButton()
        context.presenter.addressDidCopied()
        context.presenter.didPullToRefresh()
        XCTAssertEqual(context.wireframe.calls, ["close", "send", "receive", "crossChain", "polkaswap", "locked"])
        XCTAssertTrue(context.wireframe.chainAssets.allSatisfy { $0.chain.chainId == chainAsset.chain.chainId })
        XCTAssertEqual(context.wireframe.statusCount, 1)
        XCTAssertEqual(context.interactor.calls, ["updateData"])
    }

    func testSendIsRefusedOnTaira() throws {
        let context = CovHChainAccountPresenterContext(chainAsset: try CovHChainAccountFixture.tairaChainAsset())
        context.presenter.didTapSendButton()
        XCTAssertTrue(context.wireframe.calls.isEmpty)
    }

    func testBuyOffersTheAssetProvidersAndOpensTheSelectedOne() throws {
        let context = CovHChainAccountPresenterContext(chainAsset: CovHChainAccountFixture.chainAsset(providers: [.ramp]))
        context.presenter.didTapBuyButton()
        XCTAssertEqual(context.wireframe.calls, ["buy"])
        let items = try XCTUnwrap(context.wireframe.buyItems.first)
        XCTAssertEqual(items.map(\.title), ["Ramp"])
        XCTAssertTrue(context.wireframe.buyDelegates.first === context.presenter)
        context.presenter.modalPickerDidSelectModelAtIndex(0, context: nil)
        XCTAssertEqual(context.wireframe.purchaseActions.map(\.title), ["Ramp"])
        XCTAssertEqual(context.wireframe.purchaseActions.first?.url.host, "app.ramp.network")
    }

    func testOptionsAskForExportOptionsOfTheWalletAddress() throws {
        let context = CovHChainAccountPresenterContext(chainAsset: CovHChainAccountFixture.chainAsset())
        context.presenter.didTapOptionsButton()
        XCTAssertEqual(context.interactor.exportAddresses, [try XCTUnwrap(context.address)])
    }

    func testExportOptionsMenuRoutesEveryAction() throws {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let context = CovHChainAccountPresenterContext(chainAsset: chainAsset)
        context.interactor.claimAvailable = true
        context.presenter.didReceiveExportOptions(options: [.mnemonic])
        let items = try XCTUnwrap(context.wireframe.actionItems.first)
        XCTAssertEqual(items.map(CovHChainAccountFixture.actionName), ["export", "switchNode", "replace", "claim"])
        let callback = try XCTUnwrap(context.wireframe.actionCallbacks.first)
        for index in items.indices {
            callback(index)
        }
        XCTAssertEqual(context.wireframe.calls, ["actions", "export", "node", "replace", "claim"])
        XCTAssertEqual(context.wireframe.exportOptions, [[.mnemonic]])
        XCTAssertEqual(context.wireframe.exportAddresses, [try XCTUnwrap(context.address)])
    }

    func testReplaceFlowOffersCreateAfterWarningAndImport() throws {
        let context = CovHChainAccountPresenterContext(chainAsset: CovHChainAccountFixture.chainAsset())
        context.presenter.didReceiveExportOptions(options: [])
        let actionCallback = try XCTUnwrap(context.wireframe.actionCallbacks.first)
        actionCallback(2)
        XCTAssertEqual(context.wireframe.replaceItems.first, [.create, .import])
        let replaceCallback = try XCTUnwrap(context.wireframe.replaceCallbacks.first)

        replaceCallback(0)
        let sheet = try XCTUnwrap(context.wireframe.sheets.first)
        XCTAssertEqual(sheet.actions.count, 1)
        XCTAssertFalse(sheet.title.isEmpty)
        XCTAssertFalse(context.wireframe.calls.contains("create"))
        sheet.actions.first?.handler?()

        replaceCallback(1)
        XCTAssertEqual(Array(context.wireframe.calls.suffix(2)), ["create", "import"])
        XCTAssertTrue(context.wireframe.uniqueModels.allSatisfy { $0.meta.metaId == context.wallet.metaId })
    }

    func testBaseActionsDependOnChainKind() throws {
        let substrate = CovHChainAccountFixture.chainAsset().chain
        let ethereum = CovHChainAccountFixture.chainAsset(options: [.ethereum]).chain
        let bitcoin = try CovHChainAccountFixture.bitcoinChainAsset().chain
        XCTAssertEqual(ChainAccountPresenter.baseActions(for: substrate).map(CovHChainAccountFixture.actionName), ["export", "switchNode", "replace"])
        XCTAssertEqual(ChainAccountPresenter.baseActions(for: ethereum).map(CovHChainAccountFixture.actionName), ["export", "replace"])
        XCTAssertTrue(ChainAccountPresenter.baseActions(for: bitcoin).isEmpty)
    }

    func testSelectNetworkPassesSelectionByMode() {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let extended = CovHChainAccountPresenterContext(chainAsset: chainAsset, mode: .extended)
        extended.interactor.availableChainAssets = [chainAsset, chainAsset]
        extended.presenter.didTapSelectNetwork()
        XCTAssertEqual(extended.wireframe.selectedChainIds, [chainAsset.chain.chainId])
        XCTAssertEqual(extended.wireframe.selectChainModels.first??.map(\.chainId), [chainAsset.chain.chainId])
        XCTAssertTrue(extended.wireframe.selectDelegates.first ?? nil === extended.presenter)

        let simple = CovHChainAccountPresenterContext(chainAsset: chainAsset, mode: .simple)
        simple.presenter.didTapSelectNetwork()
        XCTAssertEqual(simple.wireframe.selectedChainIds.count, 1)
        XCTAssertNil(simple.wireframe.selectedChainIds.first ?? "value")
    }

    func testChainSelectionShowsDetailsInSimpleModeAndUpdatesInExtendedMode() {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let other = CovHChainAccountFixture.chain(name: "Other")
        let selectView = CovHChainAccountSelectNetworkView()

        let simple = CovHChainAccountPresenterContext(chainAsset: chainAsset, mode: .simple)
        simple.presenter.chainSelection(view: selectView, didCompleteWith: nil, contextTag: nil)
        XCTAssertTrue(simple.wireframe.calls.isEmpty)
        simple.presenter.chainSelection(view: selectView, didCompleteWith: other, contextTag: nil)
        XCTAssertEqual(simple.wireframe.calls, ["details"])
        XCTAssertEqual(simple.wireframe.chainAssets.first?.chain.chainId, other.chainId)
        XCTAssertEqual(simple.wireframe.chainAssets.first?.asset.id, chainAsset.asset.id)

        let extended = CovHChainAccountPresenterContext(chainAsset: chainAsset, mode: .extended)
        extended.presenter.chainSelection(view: selectView, didCompleteWith: other, contextTag: 1)
        XCTAssertEqual(extended.interactor.updatedChains.map(\.chainId), [other.chainId])
        XCTAssertTrue(extended.wireframe.calls.isEmpty)
    }

    func testAvailableChainAssetsReplaceBalanceOnlyInSimpleMode() {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let simple = CovHChainAccountPresenterContext(chainAsset: chainAsset, mode: .simple)
        simple.presenter.didReceive(availableChainAssets: [chainAsset])
        guard case let .chainAssets(chainAssets, wallet) = simple.balanceModule.infoTypes.first else {
            return XCTFail("Simple mode shows the balance of every available chain asset")
        }
        XCTAssertEqual(chainAssets.map(\.chain.chainId), [chainAsset.chain.chainId])
        XCTAssertEqual(wallet.metaId, simple.wallet.metaId)

        let extended = CovHChainAccountPresenterContext(chainAsset: chainAsset, mode: .extended)
        extended.presenter.didReceive(availableChainAssets: [chainAsset])
        XCTAssertTrue(extended.balanceModule.infoTypes.isEmpty)
    }

    func testChainAssetUpdateRefreshesViewBalanceAndHistory() {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let extended = CovHChainAccountPresenterContext(chainAsset: chainAsset, mode: .extended)
        extended.presenter.didUpdate(chainAsset: chainAsset)
        CovHChainAccountFixture.spin { !extended.view.states.isEmpty }
        XCTAssertEqual(extended.view.loadedModels.count, 1)
        guard case let .chainAsset(_, replaced) = extended.balanceModule.infoTypes.first else {
            return XCTFail("Extended mode follows the selected chain asset")
        }
        XCTAssertEqual(replaced.chain.chainId, chainAsset.chain.chainId)
        XCTAssertEqual(extended.output.updates.compactMap { $0?.chain.chainId }, [chainAsset.chain.chainId])

        let simple = CovHChainAccountPresenterContext(chainAsset: chainAsset, mode: .simple)
        simple.presenter.didUpdate(chainAsset: chainAsset)
        XCTAssertTrue(simple.balanceModule.infoTypes.isEmpty)
        XCTAssertEqual(simple.output.updates.count, 1)
    }

    func testWalletChangeRebuildsViewModelForTheNewWallet() {
        let context = CovHChainAccountPresenterContext(chainAsset: CovHChainAccountFixture.chainAsset())
        let replacement = CovHChainAccountFixture.wallet()
        context.presenter.didReceiveWallet(wallet: replacement)
        CovHChainAccountFixture.spin { !context.view.states.isEmpty }
        XCTAssertEqual(context.view.loadedModels.map(\.walletName), [replacement.name])
        XCTAssertEqual(context.presenter.wallet.metaId, replacement.metaId)
        context.presenter.didTapReceiveButton()
        XCTAssertEqual(context.wireframe.calls, ["receive"])
    }
}
