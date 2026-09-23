import XCTest
@testable import TonSwift

final class AddressTest: XCTestCase {

    func testAddress() throws {
        // should parse addresses in various forms
        let address1 = try FriendlyAddress(string:"0QAs9VlT6S776tq3unJcP5Ogsj-ELLunLXuOb1EKcOQi4-QO")
        let address2 = try FriendlyAddress(string:"kQAs9VlT6S776tq3unJcP5Ogsj-ELLunLXuOb1EKcOQi47nL")
        let address3 = try Address.parse(raw: "0:2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3")
        XCTAssertFalse(address1.isBounceable)
        XCTAssertTrue(address2.isBounceable)
        XCTAssertTrue(address1.isTestOnly)
        XCTAssertTrue(address2.isTestOnly)
        XCTAssertEqual(address1.address.workchain, 0)
        XCTAssertEqual(address2.address.workchain, 0)
        XCTAssertEqual(address3.workchain, 0)
        XCTAssertEqual(address1.address.hash, Data(hex: "2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3"))
        XCTAssertEqual(address2.address.hash, Data(hex: "2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3"))
        XCTAssertEqual(address3.hash, Data(hex: "2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3"))
        XCTAssertEqual(address1.address.toRaw(), "0:2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3")
        XCTAssertEqual(address2.address.toRaw(), "0:2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3")
        XCTAssertEqual(address3.toRaw(), "0:2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3")
        
        // should serialize to friendly form
        let address = try Address.parse(raw: "0:2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3")
        
        // Bounceable
        XCTAssertEqual(address.toString(), "EQAs9VlT6S776tq3unJcP5Ogsj-ELLunLXuOb1EKcOQi4wJB")
        XCTAssertEqual(address.toString(testOnly: true), "kQAs9VlT6S776tq3unJcP5Ogsj-ELLunLXuOb1EKcOQi47nL")
        XCTAssertEqual(address.toString(urlSafe: false), "EQAs9VlT6S776tq3unJcP5Ogsj+ELLunLXuOb1EKcOQi4wJB")
        XCTAssertEqual(address.toString(urlSafe: false, testOnly: true), "kQAs9VlT6S776tq3unJcP5Ogsj+ELLunLXuOb1EKcOQi47nL")
        
        // Non-Bounceable
        XCTAssertEqual(address.toString(bounceable: false), "UQAs9VlT6S776tq3unJcP5Ogsj-ELLunLXuOb1EKcOQi41-E")
        XCTAssertEqual(address.toString(testOnly: true, bounceable: false), "0QAs9VlT6S776tq3unJcP5Ogsj-ELLunLXuOb1EKcOQi4-QO")
        XCTAssertEqual(address.toString(urlSafe: false, bounceable: false), "UQAs9VlT6S776tq3unJcP5Ogsj+ELLunLXuOb1EKcOQi41+E")
        XCTAssertEqual(address.toString(urlSafe: false, testOnly: true, bounceable: false), "0QAs9VlT6S776tq3unJcP5Ogsj+ELLunLXuOb1EKcOQi4+QO")
        
        // should implement equals
        let addr1 = try Address.parse(raw: "0:2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3")
        let addr2 = try Address.parse(raw: "0:2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3")
        let addr3 = try Address.parse(raw: "-1:2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3")
        let addr4 = try Address.parse(raw: "0:2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e5")
        XCTAssertEqual(addr1, addr2)
        XCTAssertEqual(addr2, addr1)
        XCTAssertNotEqual(addr2, addr4)
        XCTAssertNotEqual(addr2, addr3)
        XCTAssertNotEqual(addr4, addr3)
    }
}
