import BigInt
import IrohaCrypto
import SSFExtrinsicKit
import SSFModels
import SSFSigner
import SSFUtils
import XCTest
@testable import fearless

final class CovFSubstrateTransferTests: XCTestCase {
    func testEstimateAndSubmitForwardCallAmountReceiverAndOptionalTip() async throws {
        let fixture = try CovFSubstrateFixture()
        for tip: BigUInt? in [nil, 7] {
            let transfer = try fixture.transfer(tip: tip)
            let fee = try await fixture.service.estimateFee(for: transfer)
            XCTAssertEqual(fee, 6)
            XCTAssertEqual(fixture.factory.receiver, CovFFixtures.account)
            XCTAssertEqual(fixture.factory.amount, 123)
            XCTAssertEqual(fixture.factory.asset, transfer.chainAsset)
            XCTAssertEqual(fixture.extrinsic.builder.names, ["transfer"])
            XCTAssertEqual(fixture.extrinsic.builder.tip, tip)
            let hash = try await fixture.service.submit(transfer: transfer)
            XCTAssertEqual(hash, "0xsubmitted")
            XCTAssertEqual(fixture.extrinsic.builder.names, ["transfer"])
            XCTAssertEqual(fixture.extrinsic.builder.tip, tip)
            XCTAssertTrue(fixture.extrinsic.signer === fixture.signer)
        }
    }

    func testInvalidReceiverUsesTemporaryAccountForFeeButCannotSubmit() async throws {
        let fixture = try CovFSubstrateFixture()
        let transfer = Transfer(chainAsset: CovFFixtures.asset(), amount: 123, receiver: "bad-address", tip: nil, appId: nil)
        let fee = try await fixture.service.estimateFee(for: transfer)
        XCTAssertEqual(fee, 6)
        XCTAssertEqual(fixture.factory.receiver?.count, 32)
        do { _ = try await fixture.service.submit(transfer: transfer); XCTFail("Invalid receiver cannot be submitted") }
        catch { XCTAssertNil(fixture.extrinsic.signer) }
    }

    func testFeeSubscriptionReportsFeeAndErrorsAndBuildsTip() throws {
        let fixture = try CovFSubstrateFixture()
        let listener = CovFSubstrateFeeListener()
        fixture.service.subscribeForFee(transfer: try fixture.transfer(tip: 9), listener: listener)
        XCTAssertEqual(listener.fees, [6])
        XCTAssertEqual(fixture.extrinsic.builder.tip, 9)
        fixture.extrinsic.failure = NSError(domain: "extrinsic", code: 1)
        let invalid = Transfer(chainAsset: CovFFixtures.asset(), amount: 1, receiver: "invalid", tip: nil, appId: nil)
        fixture.service.subscribeForFee(transfer: invalid, listener: listener)
        XCTAssertEqual(listener.errors.map { ($0 as NSError).domain }, ["extrinsic"])
        XCTAssertEqual(fixture.factory.receiver?.count, 32)
    }

    func testAsyncEstimateAndSubmitPropagateErrors() async throws {
        let fixture = try CovFSubstrateFixture()
        fixture.extrinsic.failure = NSError(domain: "extrinsic", code: 2)
        let transfer = try fixture.transfer()
        do { _ = try await fixture.service.estimateFee(for: transfer); XCTFail("Expected fee error") }
        catch { XCTAssertEqual((error as NSError).code, 2) }
        do { _ = try await fixture.service.submit(transfer: transfer); XCTFail("Expected submit error") }
        catch { XCTAssertEqual((error as NSError).code, 2) }
    }

    func testXorlessTransferUsesDedicatedCallForFeeAndSubmission() async throws {
        let fixture = try CovFSubstrateFixture()
        let transfer = fixture.xorless()
        let fee = try await fixture.service.estimateFee(for: transfer)
        XCTAssertEqual(fee, 6)
        XCTAssertEqual(fixture.factory.xorless?.amount, transfer.amount)
        XCTAssertEqual(fixture.factory.xorless?.receiver, transfer.receiver)
        XCTAssertEqual(fixture.extrinsic.builder.names, ["xorless"])
        let hash = try await fixture.service.submit(transfer: transfer)
        XCTAssertEqual(hash, "0xsubmitted")
        XCTAssertEqual(fixture.extrinsic.builder.names, ["xorless"])
        XCTAssertNil(fixture.extrinsic.builder.tip)
    }

    func testXorlessTransferPropagatesFeeAndSubmissionFailures() async throws {
        let fixture = try CovFSubstrateFixture()
        fixture.extrinsic.failure = NSError(domain: "xorless", code: 3)
        do { _ = try await fixture.service.estimateFee(for: fixture.xorless()); XCTFail("Expected fee error") }
        catch { XCTAssertEqual((error as NSError).domain, "xorless") }
        do { _ = try await fixture.service.submit(transfer: fixture.xorless()); XCTFail("Expected submit error") }
        catch { XCTAssertEqual((error as NSError).domain, "xorless") }
    }
}

private final class CovFSubstrateFixture {
    let extrinsic = CovFExtrinsic()
    let factory: CovFTransferCallFactory
    let signer = CovFTransferSigner()
    lazy var service = SubstrateTransferService(extrinsicService: extrinsic, callFactory: factory, signer: signer)

    init() throws {
        let runtime = try CovFFixtures.runtime(path: .activeEra, type: "u32", definitions: #"{"types":{}}"#)
        factory = CovFTransferCallFactory(runtimeService: runtime)
    }

    func transfer(tip: BigUInt? = nil) throws -> Transfer {
        let asset = CovFFixtures.asset()
        return Transfer(chainAsset: asset, amount: 123, receiver: try AddressFactory.address(for: CovFFixtures.account, chain: asset.chain), tip: tip, appId: 4)
    }

    func xorless() -> XorlessTransfer {
        XorlessTransfer(
            dexId: "0", assetId: fearless.SoraAssetId(wrappedValue: "0x01"), receiver: CovFFixtures.account,
            amount: 123, desiredXorAmount: 2, maxAmountIn: 140, selectedSourceTypes: [],
            filterMode: PolkaswapCallFilterModeType(wrappedName: "Disabled", wrappedValue: nil), additionalData: Data()
        )
    }
}

private final class CovFTransferCallFactory: SubstrateCallFactoryDefault {
    var receiver: Data?
    var amount: BigUInt?
    var asset: ChainAsset?
    var xorless: XorlessTransfer?
    override func transfer(to receiver: AccountId, amount: BigUInt, chainAsset: ChainAsset) -> any RuntimeCallable {
        self.receiver = receiver
        self.amount = amount
        asset = chainAsset
        return RuntimeCall(moduleName: "Balances", callName: "transfer")
    }

    override func xorlessTransfer(_ transfer: XorlessTransfer) -> any RuntimeCallable {
        xorless = transfer
        return RuntimeCall(moduleName: "LiquidityProxy", callName: "xorless")
    }
}

private final class CovFTransferSigner: TransactionSignerProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol { throw NSError(domain: "unexpected signing", code: 1) }
}

private final class CovFSubstrateFeeListener: TransferFeeEstimationListener {
    var fees: [BigUInt] = []
    var errors: [Error] = []
    func didReceiveFee(fee: BigUInt) { fees.append(fee) }
    func didReceiveFeeError(feeError: Error) { errors.append(feeError) }
}

private final class CovFExtrinsic: SSFExtrinsicKit.ExtrinsicServiceProtocol {
    var failure: Error?
    var builder = CovFTransferBuilder()
    var signer: TransactionSignerProtocol?

    func estimateFee(
        _ closure: @escaping SSFExtrinsicKit.ExtrinsicBuilderClosure, runningIn _: DispatchQueue,
        completion: @escaping SSFExtrinsicKit.EstimateFeeClosure
    ) {
        do {
            builder = CovFTransferBuilder()
            _ = try closure(builder)
            if let failure { throw failure }
            completion(.success(SSFExtrinsicKit.RuntimeDispatchInfo(inclusionFee: .init(baseFee: 1, lenFee: 2, adjustedWeightFee: 3))))
        } catch { completion(.failure(error)) }
    }

    func submit(
        _ closure: @escaping SSFExtrinsicKit.ExtrinsicBuilderClosure, signer: TransactionSignerProtocol,
        runningIn _: DispatchQueue, completion: @escaping SSFExtrinsicKit.ExtrinsicSubmitClosure
    ) {
        do {
            self.signer = signer
            builder = CovFTransferBuilder()
            _ = try closure(builder)
            if let failure { throw failure }
            completion(.success("0xsubmitted"))
        } catch { completion(.failure(error)) }
    }

    func estimateFee(
        _: @escaping SSFExtrinsicKit.ExtrinsicBuilderIndexedClosure, runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int, completion: @escaping SSFExtrinsicKit.EstimateFeeIndexedClosure
    ) { completion([]) }

    func submit(
        _: @escaping SSFExtrinsicKit.ExtrinsicBuilderIndexedClosure, signer _: TransactionSignerProtocol,
        runningIn _: DispatchQueue, numberOfExtrinsics _: Int, completion: @escaping SSFExtrinsicKit.ExtrinsicSubmitIndexedClosure
    ) { completion([]) }

    func submitAndWatch(
        _: @escaping SSFExtrinsicKit.ExtrinsicBuilderClosure, signer _: TransactionSignerProtocol,
        runningIn _: DispatchQueue, completion: @escaping SSFExtrinsicKit.ExtrinsicSubmitAndWatchClosure
    ) { completion(.failure(NSError(domain: "unexpected watch", code: 1)), nil) }
}

private final class CovFTransferBuilder: ExtrinsicBuilderProtocol {
    var names: [String] = []
    var tip: BigUInt?
    func with<A: Codable>(address _: A) throws -> Self { self }
    func with(nonce _: UInt32) -> Self { self }
    func with(era _: Era, blockHash _: String) -> Self { self }
    func with(tip: BigUInt) -> Self { self.tip = tip; return self }
    func with(appId _: BigUInt) -> Self { self }
    func with(shouldUseAtomicBatch _: Bool) -> Self { self }
    func adding<T: RuntimeCallable>(call: T) throws -> Self { names.append(call.callName); return self }
    func adding(rawCall _: Data) throws -> Self { self }
    func signing(
        by _: (Data) throws -> Data, of _: SSFModels.CryptoType, using _: DynamicScaleEncoding, metadata _: RuntimeMetadata
    ) throws -> Self { self }
    func build(encodingBy _: DynamicScaleEncoding, metadata _: RuntimeMetadata) throws -> Data { Data() }
    func buildSignature(encodingBy _: DynamicScaleEncoding, metadata _: RuntimeMetadata) throws -> Data { Data() }
}
