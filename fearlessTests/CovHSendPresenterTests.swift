import XCTest
import BigInt
import SSFModels
import SSFQRService
@testable import fearless

final class CovHSendPresenterTests: XCTestCase {
    func testAddressWithoutAnyNetworkWarnsAndLeaves() throws {
        let harness = CovHSendPresenterHarness(initialData: .address("unknown-address"))
        harness.interactor.possibleChains = nil
        harness.load()
        CovHSendWait.until { !harness.router.sheets.isEmpty }
        let sheet = try XCTUnwrap(harness.router.sheets.first)
        XCTAssertEqual(sheet.actions.count, 1)
        sheet.actions.first?.handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(harness.router.calls, ["dismiss", "dismiss"])
    }

    func testAddressOnOneSingleAssetNetworkSelectsThatAsset() throws {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Single", assetUtility: true)
        let harness = CovHSendPresenterHarness(initialData: .address("recipient"))
        harness.interactor.possibleChains = [chainAsset.chain]
        harness.load()
        CovHSendWait.until { !harness.interactor.updated.isEmpty }
        XCTAssertEqual(harness.view.recipients.first?.address, "recipient")
        XCTAssertEqual(harness.view.recipients.first?.canEditing, true)
        XCTAssertEqual(harness.interactor.updated.map(\.asset.id), [chainAsset.asset.id])
        XCTAssertEqual(harness.interactor.scamRequests, ["recipient"])
    }

    func testAddressOnSeveralNetworksAsksForNetworkThenAsset() throws {
        let first = CovHSendFixtures.asset(id: "one", symbol: "ONE", utility: true)
        let second = CovHSendFixtures.asset(id: "two", symbol: "TWO", utility: false)
        let multi = CovHSendFixtures.chain(name: "Covh Multi", assets: [first, second])
        let other = CovHSendFixtures.chainAsset(chainName: "Covh Other", assetUtility: true)
        let harness = CovHSendPresenterHarness(initialData: .address("recipient"))
        harness.interactor.possibleChains = [multi, other.chain]
        harness.load()
        CovHSendWait.until { harness.router.calls.contains("network") }
        XCTAssertEqual(harness.router.networkPickerChains.first??.count, 2)

        let list = CovHCrossChainSelectNetworkView()
        harness.presenter.chainSelection(view: list, didCompleteWith: nil, contextTag: nil)
        harness.presenter.chainSelection(view: list, didCompleteWith: multi, contextTag: nil)
        XCTAssertEqual(harness.router.calls, ["network", "asset"])
        XCTAssertEqual(Set(harness.router.assetPickerOffers.last??.map(\.asset.id) ?? []), ["one", "two"])

        let selected = ChainAsset(chain: multi, asset: first)
        harness.presenter.assetSelection(didCompleteWith: selected, contextTag: nil)
        XCTAssertEqual(harness.interactor.updated.last?.asset.id, "one")

        harness.presenter.chainSelection(view: list, didCompleteWith: other.chain, contextTag: nil)
        XCTAssertEqual(harness.view.presentedSheets.count, 1, "The asset has no member on the other network")
        XCTAssertTrue(harness.view.presentedSheets.last?.message?.contains(other.chain.name) == true)
        XCTAssertEqual(harness.interactor.updated.last?.asset.id, "one", "The selection is kept")
    }

    func testMissingNetworkListOpensTheAssetPickerAndCancellingLeaves() {
        let harness = CovHSendPresenterHarness(initialData: .address("recipient"))
        harness.interactor.possibleChains = []
        harness.presenter.didReceive(possibleChains: nil)
        XCTAssertEqual(harness.router.calls, ["asset"])
        XCTAssertNil(harness.router.assetPickerOffers.first ?? nil)
        harness.presenter.assetSelection(didCompleteWith: nil, contextTag: nil)
        XCTAssertEqual(harness.router.calls, ["asset", "dismiss"])
    }

    func testToolbarActionsUseTheSelectedAsset() {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Toolbar", assetUtility: true)
        let harness = CovHSendPresenterHarness(initialData: .chainAsset(chainAsset))
        harness.load()
        harness.presenter.didTapScanButton()
        harness.presenter.didTapHistoryButton()
        harness.presenter.didTapSelectAsset()
        harness.presenter.didFinishWith(scanType: .walletConnect("wc:1"))
        XCTAssertEqual(harness.router.calls, ["scan", "history", "asset"])
        XCTAssertEqual(harness.router.historyAssets.map(\.asset.id), [chainAsset.asset.id])
        XCTAssertEqual(harness.router.assetPickerSelections, [chainAsset.asset.id])
        harness.presenter.assetSelection(didCompleteWith: nil, contextTag: nil)
        XCTAssertEqual(harness.router.calls.count, 3, "Cancelling keeps the current asset")
    }

    func testInteractorFailuresAreLoggedAndDependenciesRequestAFee() {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Callbacks", assetUtility: true)
        let harness = CovHSendPresenterHarness(initialData: .chainAsset(chainAsset))
        harness.load()
        harness.presenter.didReceiveAssetAccountInfoError(error: CovHSendError.failed)
        CovHSendWait.until { harness.view.assetBalances == 1 }
        XCTAssertEqual(harness.view.assetBalances, 1, "A failed asset record still shows the balance")
        harness.presenter.didReceiveMinimumBalance(result: .failure(CovHSendError.failed))
        harness.presenter.didReceive(eqTotalBalance: 3)
        harness.presenter.didReceive(eqTotalBalance: 4)
        harness.presenter.didReceiveTip(result: .failure(CovHSendError.failed))
        XCTAssertTrue(harness.logger.errors.contains { $0.contains("Did receive minimum balance error") })
        XCTAssertTrue(harness.logger.errors.contains { $0.contains("Did receive tip error") })
        XCTAssertEqual(harness.view.tipStops, 1)
        XCTAssertTrue(harness.interactor.estimates.isEmpty, "Without a recipient a failed tip quotes nothing")

        harness.presenter.didReceiveDependencies(for: chainAsset)
        XCTAssertEqual(harness.interactor.estimates, [.zero])
        harness.presenter.searchTextDidChanged("recipient")
        harness.presenter.didReceiveTip(result: .failure(CovHSendError.failed))
        XCTAssertEqual(harness.interactor.estimates.count, 2)
    }

    func testFeeAssetBalanceIsTrackedForTokens() {
        let native = CovHSendFixtures.asset(id: "native", symbol: "NAT", utility: true)
        let token = CovHSendFixtures.asset(id: "token", symbol: "TOK", utility: false)
        let chain = CovHSendFixtures.chain(name: "Covh Token", assets: [native, token])
        let harness = CovHSendPresenterHarness(initialData: .chainAsset(ChainAsset(chain: chain, asset: token)))
        harness.load()
        harness.presenter.didReceiveAssetAccountInfo(assetAccountInfo: nil)
        CovHSendWait.until { harness.view.assetBalances == 1 }
        let info = CovHSendPresenterHarness.accountInfo(5, precision: 9)
        harness.presenter.didReceiveAccountInfo(result: .success(info), for: ChainAsset(chain: chain, asset: native))
        CovHSendWait.until { harness.view.assetBalances == 2 }
        XCTAssertEqual(harness.view.assetBalances, 2, "The fee asset's balance refreshes the token form")
    }

    func testBokoloPaysItsFeeInXorWhenXorCoversIt() throws {
        let assets = CovHSendPresenterHarness.bokolo()
        let harness = CovHSendPresenterHarness(initialData: .chainAsset(assets.bokolo))
        harness.load()
        harness.presenter.didReceiveAccountInfo(result: .success(CovHSendPresenterHarness.accountInfo(100, precision: 18)), for: assets.bokolo)
        harness.presenter.didReceiveAccountInfo(result: .success(CovHSendPresenterHarness.accountInfo(10, precision: 18)), for: assets.xor)
        CovHSendWait.until { harness.view.feeModels.count >= 2 }
        XCTAssertTrue(harness.view.feeModels.allSatisfy { $0 == nil }, "No fee before the quote")

        harness.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(10).power(17))))
        CovHSendWait.until { harness.view.feeModels.last??.amount != nil }
        XCTAssertNotNil(harness.view.feeModels.last ?? nil)

        harness.presenter.updateAmount(1)
        XCTAssertEqual(harness.interactor.xorless.count, 1)
        XCTAssertEqual(harness.interactor.xorless.first?.receiver.count, 32)
        XCTAssertEqual(harness.interactor.xorless.first?.amount, BigUInt(10).power(18))

        harness.presenter.didTapContinueButton()
        CovHSendWait.until { !harness.router.confirmations.isEmpty }
        guard case let .xorlessTransfer(transfer)? = harness.router.confirmations.first else {
            return XCTFail("Bokolo is confirmed as a XOR-less transfer")
        }
        XCTAssertEqual(transfer.dexId, "0")
    }

    func testBokoloFeeIsConvertedWhenXorIsShort() throws {
        let assets = CovHSendPresenterHarness.bokolo()
        let harness = CovHSendPresenterHarness(initialData: .chainAsset(assets.bokolo))
        harness.interactor.convertResult = .success(SwapValues(dexId: 1, amount: "2000000000000000000", rewards: []))
        harness.load()
        harness.presenter.didReceiveAccountInfo(result: .success(CovHSendPresenterHarness.accountInfo(0.01, precision: 18)), for: assets.xor)
        harness.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(10).power(17))))
        harness.presenter.didReceiveAccountInfo(result: .success(CovHSendPresenterHarness.accountInfo(100, precision: 18)), for: assets.bokolo)
        CovHSendWait.until { harness.view.feeModels.last??.amount != nil }
        XCTAssertNotNil(harness.view.feeModels.last ?? nil, "The fee is shown in Bokolo")

        harness.presenter.updateAmount(10)
        XCTAssertEqual(harness.interactor.xorless.last?.dexId, "1")
        harness.presenter.didTapContinueButton()
        CovHSendWait.until { !harness.router.confirmations.isEmpty }
        XCTAssertEqual(harness.router.confirmations.count, 1)
    }

    func testBokoloConversionFailureIsPresented() {
        let assets = CovHSendPresenterHarness.bokolo()
        let harness = CovHSendPresenterHarness(initialData: .chainAsset(assets.bokolo))
        harness.interactor.convertResult = .failure(CovHSendError.failed)
        harness.load()
        harness.presenter.didReceiveAccountInfo(result: .success(CovHSendPresenterHarness.accountInfo(0.01, precision: 18)), for: assets.xor)
        harness.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(10).power(17))))
        CovHSendWait.until { !harness.router.errors.isEmpty }
        XCTAssertTrue(harness.router.errors.first is CovHSendError)
        XCTAssertGreaterThanOrEqual(harness.view.feeStops, 2)
    }

    func testSoraCodeSelectsTheAssetAndLocksTheAmount() throws {
        let asset = AssetModel(id: "val", name: "VAL", symbol: "VAL", precision: 18, currencyId: "0xval", isUtility: true, isNative: true)
        let sora = CovHSendFixtures.chain(name: "SORA Mainnet", assets: [asset])
        let info = SoraQRInfo(address: "sora-address", rawPublicKey: Data(), username: "", assetId: "0xval", amount: "2.5")
        let start = CovHSendFixtures.chainAsset(chainName: "Covh Start", assetUtility: true)
        let harness = CovHSendPresenterHarness(initialData: .chainAsset(start))
        harness.interactor.possibleChains = [sora]
        harness.load()
        harness.presenter.didFinishWith(scanType: .qrInfo(.sora(info)))
        CovHSendWait.until { !harness.view.blocked.isEmpty }
        XCTAssertEqual(harness.view.blocked, [false])
        XCTAssertEqual(harness.view.recipients.last?.address, "sora-address")
        XCTAssertEqual(harness.view.recipients.last?.canEditing, false)
        XCTAssertEqual(harness.interactor.updated.last?.asset.id, "val")
    }
}
