import Foundation
import SSFModels
import XCTest
@testable import fearless

final class EthereumNodeFetchingTests: XCTestCase {
    func testSelectedLegacyBlastNodeFallsBackWithoutChangingWalletOrNodeSettings() throws {
        let selected = try node("https://bsc-mainnet.blastapi.io/legacy-key")
        let supported = try node("https://bsc-rpc.publicnode.com")
        let chain = makeChain(nodes: [selected, supported], selected: selected)

        XCTAssertEqual(try EthereumNodeSelection.url(for: chain), supported.url)
        XCTAssertEqual(chain.selectedNode, selected)
        XCTAssertEqual(chain.nodes, [selected, supported])
        XCTAssertEqual(chain.chainId, "56")
    }

    func testRetiredMainDomainSubdomainsPortsUppercaseAndTrailingDotAreExcluded() throws {
        for retired in [
            "https://blastapi.io",
            "https://eth-mainnet.blastapi.io/old-key",
            "wss://bsc-mainnet.blastapi.io:443/old-key",
            "https://ETH-MAINNET.BLASTAPI.IO/old-key",
            "https://eth-mainnet.blastapi.io./old-key",
            "https://eth-mainnet%2Eblastapi%2Eio/old-key",
        ] {
            let legacy = try node(retired)
            let supported = try node("https://public.example/rpc")
            let chain = makeChain(nodes: [legacy, supported], selected: legacy)
            XCTAssertEqual(try EthereumNodeSelection.url(for: chain), supported.url, retired)
        }
    }

    func testCustomDomainLookalikesAndPathsArePreserved() throws {
        for custom in [
            "https://notblastapi.io/v1",
            "https://blastapi.io.custom.example/v1",
            "https://custom.example/blastapi.io/old-key?provider=blastapi.io",
        ] {
            let selected = try node(custom)
            let chain = makeChain(nodes: [], selected: selected)
            XCTAssertEqual(try EthereumNodeSelection.url(for: chain).absoluteString, custom)
        }
    }

    func testSelectedCustomHTTPSPreservesExactPathQueryPortAndCredentials() throws {
        let value = "https://user:synthetic-password@custom.example:8443/rpc/v2/already%2Fencoded?token=existing%2Btoken&mode=full"
        let selected = try node(value)
        let chain = makeChain(nodes: [try node("https://a-public.example")], selected: selected)
        XCTAssertEqual(try EthereumNodeSelection.url(for: chain).absoluteString, value)
    }

    func testSelectedCustomWSSIsHonoredEvenWhenCatalogHasHTTPS() throws {
        let value = "wss://custom.example:9443/ws/v1?token=existing%2Btoken"
        let selected = try node(value)
        let chain = makeChain(nodes: [try node("https://a-public.example")], selected: selected)
        XCTAssertEqual(try EthereumNodeSelection.url(for: chain).absoluteString, value)
    }

    func testRegistryHTTPSSelectionIsStableAcrossSetOrders() throws {
        let a = try node("https://a-public.example/rpc?key=already-present")
        let z = try node("https://z-public.example/rpc")
        let ws = try node("wss://0-public.example/ws")
        let retired = try node("https://0.blastapi.io")
        for ordering in [[z, ws, a, retired], [retired, a, z, ws], [ws, z, retired, a]] {
            XCTAssertEqual(try EthereumNodeSelection.url(for: makeChain(nodes: Set(ordering))), a.url)
        }
    }

    func testWSSFallbackPreservesCatalogURLWithoutAnyCredentialAppend() throws {
        let expected = try node("wss://a-public.example/ws/v1?key=existing")
        let chain = makeChain(nodes: [try node("https://bsc-mainnet.blastapi.io/old"), expected])
        XCTAssertEqual(try EthereumNodeSelection.url(for: chain), expected.url)
    }

    func testWSSChoiceIsDeterministicWhenHTTPSIsUnavailable() throws {
        let expected = try node("wss://a-public.example/ws")
        let chain = makeChain(nodes: [try node("wss://z-public.example/ws"), expected])
        XCTAssertEqual(try EthereumNodeSelection.url(for: chain), expected.url)
    }

    func testUnsupportedSelectedTransportFallsBackToSupportedRegistryNode() throws {
        let expected = try node("https://public.example/rpc")
        for invalid in ["http://custom.example/rpc", "ws://custom.example/ws", "file:///tmp/rpc", "https://./rpc"] {
            let chain = makeChain(nodes: [expected], selected: try node(invalid))
            XCTAssertEqual(try EthereumNodeSelection.url(for: chain), expected.url)
        }
    }

    func testOnlyRetiredOrIncompatibleNodesReturnsActionableFailure() throws {
        let selected = try node("wss://bsc-mainnet.blastapi.io/legacy")
        let chain = makeChain(nodes: [selected, try node("http://public.example")], selected: selected)
        XCTAssertThrowsError(try EthereumNodeSelection.url(for: chain)) { error in
            XCTAssertEqual(error as? EthereumNodeFetchingError, .noSupportedNode(chainName: chain.name))
            XCTAssertTrue(error.localizedDescription.contains("network settings"))
            XCTAssertFalse(error.localizedDescription.contains("legacy"))
        }
        XCTAssertThrowsError(try EthereumNodeFetching().getNode(for: chain))
    }

    func testEmptyRegistryReturnsActionableFailureWithoutInventingProvider() {
        let chain = makeChain(nodes: [])
        XCTAssertThrowsError(try EthereumNodeSelection.url(for: chain)) { error in
            XCTAssertEqual(error as? EthereumNodeFetchingError, .noSupportedNode(chainName: chain.name))
        }
    }

    func testHTTPSNodeConstructionUsesSupportedCatalogWithoutNetworkMutation() throws {
        let chain = makeChain(nodes: [try node("https://public.example/rpc?key=existing")])
        XCTAssertNoThrow(try EthereumNodeFetching().getNode(for: chain))
        XCTAssertNil(chain.selectedNode)
    }

    private func node(_ value: String) throws -> ChainNodeModel {
        ChainNodeModel(url: try XCTUnwrap(URL(string: value)), name: "Synthetic node", apikey: nil)
    }

    private func makeChain(nodes: Set<ChainNodeModel>, selected: ChainNodeModel? = nil) -> ChainModel {
        ChainModel(
            rank: 1,
            disabled: false,
            chainId: "56",
            paraId: nil,
            name: "BNB Smart Chain",
            xcm: nil,
            nodes: nodes,
            addressPrefix: 0,
            icon: nil,
            options: [.ethereum],
            selectedNode: selected,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}
