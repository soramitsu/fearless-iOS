//import XCTest
//import SoraKeystore
//import BigInt
//import IrohaCrypto
//@testable import fearless
//
//class ExtrinsicServiceTests: XCTestCase {
//
//    private func createExtrinsicBuilderClosure(amount: BigUInt) -> ExtrinsicBuilderClosure {
//        let callFactory = SubstrateCallFactory()
//
//        let closure: ExtrinsicBuilderClosure = { builder in
//            let call = callFactory.bondExtra(amount: amount)
//            _ = try builder.adding(call: call)
//            return builder
//        }
//
//        return closure
//    }
//
//    private func createExtrinsicBuilderClosure(for batch: [PayoutInfo]) -> ExtrinsicBuilderClosure {
//        let callFactory = SubstrateCallFactory()
//
//        let closure: ExtrinsicBuilderClosure = { builder in
//            try batch.forEach { payout in
//                let payoutCall = try callFactory.payout(
//                    validatorId: payout.validator,
//                    era: payout.era
//                )
//
//                _ = try builder.adding(call: payoutCall)
//            }
//
//            return builder
//        }
//
//        return closure
//    }
//
//    func testEstimateFeeForBondExtraCall() throws {
//        let chainId = Chain.kusama.genesisHash
//        let chainFormat = ChainFormat.substrate(2)
//        let selectedAddress = "FiLhWLARS32oxm4s64gmEMSppAdugsvaAx1pCjweTLGn5Rf"
//        let selectedAccountId = try selectedAddress.toAccountId()
//        let assetPrecision: Int16 = 12
//
//        let storageFacade = SubstrateStorageTestFacade()
//
//        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
//
//        let connection = chainRegistry.getConnection(for: chainId)!
//        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
//
//        let extrinsicService = ExtrinsicService(
//            accountId: selectedAccountId,
//            chainFormat: chainFormat,
//            cryptoType: .sr25519,
//            runtimeRegistry: runtimeService,
//            engine: connection,
//            operationManager: OperationManagerFacade.sharedManager
//        )
//
//        let feeExpectation = XCTestExpectation()
//        let closure = createExtrinsicBuilderClosure(amount: 10)
//        extrinsicService.estimateFee(closure, runningIn: .main) { result in
//            switch result {
//            case let .success(paymentInfo):
//                if
//                    let feeValue = BigUInt(paymentInfo.fee),
//                    let fee = Decimal.fromSubstrateAmount(feeValue, precision: assetPrecision),
//                    fee > 0 {
//                    feeExpectation.fulfill()
//                } else {
//                    XCTFail("Cant parse fee")
//                }
//            case let .failure(error):
//                XCTFail(error.localizedDescription)
//            }
//        }
//
//        wait(for: [feeExpectation], timeout: 10)
//    }
//
//    func testEstimateFeeForPayoutRewardsCall() throws {
//        let chainId = Chain.kusama.genesisHash
//        let chainFormat = ChainFormat.substrate(2)
//        let selectedAddress = "FiLhWLARS32oxm4s64gmEMSppAdugsvaAx1pCjweTLGn5Rf"
//        let selectedAccountId = try selectedAddress.toAccountId()
//        let assetPrecision: Int16 = 12
//
//        let storageFacade = SubstrateStorageTestFacade()
//
//        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
//
//        let connection = chainRegistry.getConnection(for: chainId)!
//        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
//
//        let extrinsicService = ExtrinsicService(
//            accountId: selectedAccountId,
//            chainFormat: chainFormat,
//            cryptoType: .sr25519,
//            runtimeRegistry: runtimeService,
//            engine: connection,
//            operationManager: OperationManagerFacade.sharedManager
//        )
//
//        let feeExpectation = XCTestExpectation()
//        let payouts = [
//            PayoutInfo(era: 1000, validator: selectedAccountId, reward: 100.0, identity: nil),
//            PayoutInfo(era: 1001, validator: selectedAccountId, reward: 100.0, identity: nil),
//            PayoutInfo(era: 1002, validator: selectedAccountId, reward: 100.0, identity: nil)
//        ]
//        let closure = createExtrinsicBuilderClosure(for: payouts)
//        extrinsicService.estimateFee(closure, runningIn: .main) { result in
//            switch result {
//            case let .success(paymentInfo):
//                if
//                    let feeValue = BigUInt(paymentInfo.fee),
//                    let fee = Decimal.fromSubstrateAmount(feeValue, precision: assetPrecision),
//                    fee > 0 {
//                    feeExpectation.fulfill()
//                } else {
//                    XCTFail("Cant parse fee")
//                }
//            case let .failure(error):
//                XCTFail(error.localizedDescription)
//            }
//        }
//
//        wait(for: [feeExpectation], timeout: 20)
//    }
//
//    func testEstimateFeeForAddRemark() throws {
//        let cryptoType = CryptoType.sr25519
//        let selectedAccount = "FiLhWLARS32oxm4s64gmEMSppAdugsvaAx1pCjweTLGn5Rf"
//        let chain = Chain.westend
//
//        let settings = InMemorySettingsManager()
//        let walletFactory = WalletPrimitiveFactory(settings: settings)
//        let asset = walletFactory.createAssetForAddressType(chain.addressType)
//
//        WebSocketService.shared.setup()
//        let connection = WebSocketService.shared.connection!
//        let runtimeService = RuntimeRegistryFacade.sharedService
//        runtimeService.setup()
//
//        let extrinsicService = ExtrinsicService(
//            address: selectedAccount,
//            cryptoType: cryptoType,
//            runtimeRegistry: runtimeService,
//            engine: connection,
//            operationManager: OperationManagerFacade.sharedManager
//        )
//
//        let feeExpectation = XCTestExpectation()
//        let callFactory = SubstrateCallFactory()
//        
//        let randomBytes = (0...1000).map { _ in UInt8.random(in: 0...UInt8.max) }
//        let data = Data(randomBytes)
//        
//        let closure: ExtrinsicBuilderClosure = { builder in
//            let call = callFactory.addRemark(data)
//            _ = try builder.adding(call: call)
//            return builder
//        }
//        
//        extrinsicService.estimateFee(closure, runningIn: .main) { result in
//            switch result {
//            case let .success(paymentInfo):
//                if
//                    let feeValue = BigUInt(paymentInfo.fee),
//                    let fee = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision),
//                    fee > 0 {
//                    feeExpectation.fulfill()
//                } else {
//                    XCTFail("Cant parse fee")
//                }
//            case let .failure(error):
//                XCTFail(error.localizedDescription)
//                feeExpectation.fulfill()
//            }
//        }
//
//        wait(for: [feeExpectation], timeout: 20)
//    }
//}
