import Foundation
@testable import SSFUtils
import XCTest

final class WebSocketEngineUnsubscriptionMethodTests: XCTestCase {
    func testEachSubscriptionMethodMapsToItsUnsubscribeMethod() {
        // Unsubscribe names as SORA mainnet lists them in rpc_methods.
        let expected = [
            "state_subscribeStorage": "state_unsubscribeStorage",
            "state_subscribeRuntimeVersion": "state_unsubscribeRuntimeVersion",
            "chain_subscribeRuntimeVersion": "chain_unsubscribeRuntimeVersion",
            "chain_subscribeNewHeads": "chain_unsubscribeNewHeads",
            "chain_subscribeNewHead": "chain_unsubscribeNewHead",
            "subscribe_newHead": "unsubscribe_newHead",
            "chain_subscribeFinalizedHeads": "chain_unsubscribeFinalizedHeads",
            "chain_subscribeFinalisedHeads": "chain_unsubscribeFinalisedHeads",
            "chain_subscribeAllHeads": "chain_unsubscribeAllHeads",
            "beefy_subscribeJustifications": "beefy_unsubscribeJustifications",
            "author_submitAndWatchExtrinsic": "author_unwatchExtrinsic",
            "eth_subscribe": "eth_unsubscribe"
        ]

        for (subscribeMethod, unsubscribeMethod) in expected {
            XCTAssertEqual(
                WebSocketEngine.unsubscriptionMethod(forSubscriptionMethod: subscribeMethod),
                unsubscribeMethod,
                subscribeMethod
            )
        }
        XCTAssertNil(WebSocketEngine.unsubscriptionMethod(forSubscriptionMethod: "system_health"))
    }

    func testMethodIsReadFromTheSubscribeRequest() {
        let request = Data(#"{"id":7,"jsonrpc":"2.0","method":"state_subscribeStorage","params":[["0x26aa"]]}"#.utf8)

        XCTAssertEqual(
            WebSocketEngine.unsubscriptionMethod(forSubscriptionRequest: request),
            "state_unsubscribeStorage"
        )
        XCTAssertNil(WebSocketEngine.unsubscriptionMethod(forSubscriptionRequest: Data()))
        XCTAssertNil(WebSocketEngine.unsubscriptionMethod(forSubscriptionRequest: Data("invalid-json".utf8)))
    }
}
