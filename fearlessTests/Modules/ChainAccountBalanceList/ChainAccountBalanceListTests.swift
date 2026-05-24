import XCTest
import SSFModels
@testable import fearless

final class ChainAccountBalanceListTests: XCTestCase {
    func testBuildChainAccountViewModel_whenWalletHasAccount_thenIncludesAddressAndAsset() throws {
        let asset = makeAsset(id: "xor", symbol: "XOR")
        let chain = makeChain(name: "SORA Mainnet", asset: asset)
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Main wallet")
        let factory = makeFactory()

        let viewModel = factory.buildChainAccountViewModel(
            chainAsset: chainAsset,
            wallet: wallet,
            mode: .simple
        )
        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        let expectedAddress = try AddressFactory.address(for: account.accountId, chain: chain)

        XCTAssertEqual(viewModel.walletName, "Main wallet")
        XCTAssertEqual(viewModel.selectedChainName, "SORA Mainnet")
        XCTAssertEqual(viewModel.address, expectedAddress)
        XCTAssertEqual(viewModel.assetModel, asset)
        XCTAssertEqual(viewModel.mode, .simple)
    }

    func testBuildChainAccountViewModel_whenPolkaswapOptionPresent_thenShowsPolkaswapAndHidesBuy() {
        let asset = makeAsset(id: "xor", symbol: "XOR")
        let chain = makeChain(
            name: "SORA Mainnet",
            asset: asset,
            options: [.polkaswap]
        )
        let factory = makeFactory()

        let viewModel = factory.buildChainAccountViewModel(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            wallet: AccountGenerator.generateMetaAccount(),
            mode: .extended
        )

        XCTAssertTrue(viewModel.polkaswapButtonVisible)
        XCTAssertFalse(viewModel.buyButtonVisible)
        XCTAssertEqual(viewModel.mode, .extended)
    }

    func testBuildChainAccountViewModel_whenXcmSupportsAssetSymbol_thenShowsXcmButton() {
        let dot = makeAsset(id: "asset-dot", symbol: "DOT")
        let xcDot = makeAsset(id: "asset-xcdot", symbol: "xcDOT")
        let chain = makeChain(
            name: "Asset Hub",
            asset: xcDot,
            xcm: XcmChain(
                xcmVersion: nil,
                destWeightIsPrimitive: nil,
                availableAssets: [XcmAvailableAsset(id: dot.id, symbol: dot.symbol)],
                availableDestinations: []
            )
        )
        let factory = makeFactory()

        let viewModel = factory.buildChainAccountViewModel(
            chainAsset: ChainAsset(chain: chain, asset: xcDot),
            wallet: AccountGenerator.generateMetaAccount(),
            mode: .simple
        )

        XCTAssertTrue(viewModel.xcmButtomVisible)
    }

    func testBuildChainAccountViewModel_whenAssetNotInXcmList_thenHidesXcmButton() {
        let xor = makeAsset(id: "asset-xor", symbol: "XOR")
        let chain = makeChain(
            name: "Asset Hub",
            asset: xor,
            xcm: XcmChain(
                xcmVersion: nil,
                destWeightIsPrimitive: nil,
                availableAssets: [XcmAvailableAsset(id: "asset-dot", symbol: "DOT")],
                availableDestinations: []
            )
        )
        let factory = makeFactory()

        let viewModel = factory.buildChainAccountViewModel(
            chainAsset: ChainAsset(chain: chain, asset: xor),
            wallet: AccountGenerator.generateMetaAccount(),
            mode: .simple
        )

        XCTAssertFalse(viewModel.xcmButtomVisible)
    }

    private func makeFactory() -> ChainAccountViewModelFactory {
        ChainAccountViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
    }

    private func makeAsset(id: String, symbol: String) -> AssetModel {
        ChainModelGenerator.generateAssetWithId(id, symbol: symbol, assetPresicion: 18)
    }

    private func makeChain(
        name: String,
        asset: AssetModel,
        options: [ChainOptions]? = nil,
        xcm: XcmChain? = nil
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://node.example")!,
            name: "Node",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: UUID().uuidString,
            parentId: nil,
            paraId: nil,
            name: name,
            assets: [asset],
            xcm: xcm,
            nodes: [node],
            addressPrefix: 69,
            types: nil,
            icon: URL(string: "https://example.com/icon.png"),
            options: options,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}
