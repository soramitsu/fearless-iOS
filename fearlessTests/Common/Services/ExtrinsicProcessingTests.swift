import XCTest
import BigInt
import RobinHood
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

final class ExtrinsicProcessingTests: XCTestCase {
    func testBondExtraCall_whenCreated_thenUsesStakingBondExtraPathAndAmount() throws {
        let call = SubstrateCallFactoryDefault(runtimeService: RuntimeProviderStub())
            .bondExtra(amount: 42)
        let runtimeCall = try XCTUnwrap(call as? RuntimeCall<BondExtraCall>)

        XCTAssertEqual(runtimeCall.moduleName, "Staking")
        XCTAssertEqual(runtimeCall.callName, "bond_extra")
        XCTAssertEqual(runtimeCall.args.amount, 42)
    }

    func testPayoutCall_whenCreated_thenUsesValidatorAndEra() throws {
        let validator = Data(repeating: 7, count: 32)
        let call = try SubstrateCallFactoryDefault(runtimeService: RuntimeProviderStub())
            .payout(validatorId: validator, era: 123)
        let runtimeCall = try XCTUnwrap(call as? RuntimeCall<PayoutCall>)

        XCTAssertEqual(runtimeCall.moduleName, "Staking")
        XCTAssertEqual(runtimeCall.callName, "payout_stakers")
        XCTAssertEqual(runtimeCall.args.validatorStash, validator)
        XCTAssertEqual(runtimeCall.args.era, 123)
    }

    func testRemarkCall_whenCreated_thenUsesSystemRemarkPathAndBytes() throws {
        let remark = Data([0, 1, 2, 3, 255])
        let call = SubstrateCallFactoryDefault(runtimeService: RuntimeProviderStub())
            .addRemark(remark)
        let runtimeCall = try XCTUnwrap(call as? RuntimeCall<AddRemarkCall>)

        XCTAssertEqual(runtimeCall.moduleName, "System")
        XCTAssertEqual(runtimeCall.callName, "remark")
        XCTAssertEqual(runtimeCall.args.remark, remark)
    }
}

private final class RuntimeProviderStub: RuntimeProviderProtocol {
    var snapshot: RuntimeSnapshot?
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion

    func setup() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        throw RuntimeProviderStubError.unavailable
    }

    func cleanup() {}

    func setupHot() {}

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation {
            throw RuntimeProviderStubError.unavailable
        }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw RuntimeProviderStubError.unavailable
    }
}

private enum RuntimeProviderStubError: Error {
    case unavailable
}
