import XCTest
@testable import fearless

/// The buy picker showed one provider list and the selection indexed a list built again at tap time; when the
/// chain or wallet changed while the picker was open, the index pointed past the end (a crash) or at another provider.
final class ChainAccountBuyPickerSelectionTests: XCTestCase {
    func testSelectionOpensTheProviderThePickerShowedAfterTheChainChanged() throws {
        let context = CovHChainAccountPresenterContext(chainAsset: CovHChainAccountFixture.chainAsset(providers: [.ramp]))
        context.presenter.didTapBuyButton()
        let shown = try XCTUnwrap(context.wireframe.buyItems.first)
        XCTAssertEqual(shown.map(\.title), ["Ramp"])

        // A chain update while the picker is open: this wallet has no account on the new chain, so building the
        // provider list again gives none.
        context.interactor.chainAsset = try CovHChainAccountFixture.bitcoinChainAsset()
        context.presenter.modalPickerDidSelectModelAtIndex(0, context: nil)

        XCTAssertEqual(context.wireframe.purchaseActions.map(\.url), shown.map(\.url))
    }

    func testAnIndexOutsideThePresentedListOpensNothing() {
        let context = CovHChainAccountPresenterContext(chainAsset: CovHChainAccountFixture.chainAsset(providers: [.ramp]))
        context.presenter.didTapBuyButton()

        context.presenter.modalPickerDidSelectModelAtIndex(5, context: nil)

        XCTAssertTrue(context.wireframe.purchaseActions.isEmpty)
    }
}
