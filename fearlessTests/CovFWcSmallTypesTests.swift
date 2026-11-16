import BigInt
import XCTest
@testable import fearless

final class CovFWcSmallTypesTests: XCTestCase {
    func testRlpBigIntSerializesTwosComplementAndPadsToRequestedLength() {
        var positive = BigInt(0x1234).toRLP()
        XCTAssertEqual(positive.value, BigInt(0x1234))
        XCTAssertEqual(positive.dataLength, 2)
        XCTAssertEqual(positive.data, Data([0x12, 0x34]))
        positive.dataLength = 4
        XCTAssertEqual(positive.dataLength, 4)
        XCTAssertEqual(positive.data, Data([0x00, 0x00, 0x12, 0x34]))

        let negative = RLPBigInt(value: BigInt(-1))
        XCTAssertEqual(negative.data, Data([0xFF]))
        XCTAssertEqual(negative.dataLength, 1)
        XCTAssertEqual(RLPBigInt(value: BigInt(0)).dataLength, 0)
    }

    func testLocalToggleSetupRegistersDefaultsAndKeepsStoredValues() throws {
        let service = LocalToggleService.shared
        service.setup()
        let chains = try XCTUnwrap(service.chainsListToggle)
        XCTAssertEqual(chains.key, LocalListToggle.chains.key)
        XCTAssertEqual(chains.title, LocalListToggle.chains.title)
        service.chainsListToggle = chains
        XCTAssertEqual(service.chainsListToggle?.storageValue, chains.storageValue)
        service.chainsListToggle = nil
        XCTAssertEqual(service.chainsListToggle?.storageValue, chains.storageValue)
        XCTAssertTrue(Set(service.list.map(\.key)).isSuperset(of: ["0", "1"]))
        service.throttle()
        XCTAssertEqual(LocalToggleService.toggles.map(\.key), ["0", "1"])
    }

    func testTonEnvironmentHonorsStoredValueOnlyWhenAllowed() {
        let testnet = LocalListToggle.tonEnv.toggle()
        XCTAssertTrue(testnet.storageValue)
        XCTAssertEqual(LocalToggleService.tonEnvironment(stored: testnet, honorsStoredValue: true).storageValue, true)
        XCTAssertEqual(LocalToggleService.tonEnvironment(stored: testnet, honorsStoredValue: false).storageValue, false)
        XCTAssertEqual(LocalToggleService.tonEnvironment(stored: nil, honorsStoredValue: true).key, "1")

        let service = LocalToggleService.shared
        service.setup()
        let current = service.tonEnvListToggle
        XCTAssertEqual(current.key, "1")
        if !LocalToggleService.honorsStoredTonEnvironment {
            XCTAssertFalse(current.storageValue)
        }
        service.tonEnvListToggle = current
        XCTAssertEqual(service.tonEnvListToggle.storageValue, current.storageValue)
        XCTAssertEqual(TonChainSelection.selectedChainId(), current.storageValue ? TonChainSelection.testnetChainId : TonChainSelection.mainnetChainId)
    }
}
