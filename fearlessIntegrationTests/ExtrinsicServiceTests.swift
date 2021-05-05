import XCTest
import SoraKeystore
import BigInt
@testable import fearless

class ExtrinsicServiceTests: XCTestCase {

    private func createExtrinsicBuilderClosure(amount: BigUInt) -> ExtrinsicBuilderClosure {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            let call = callFactory.bondExtra(amount: amount)
            _ = try builder.adding(call: call)
            return builder
        }

        return closure
    }

    func testEstimateFeeForBondExtraCall() {
        let cryptoType = CryptoType.sr25519
        let selectedAccount = "FiLhWLARS32oxm4s64gmEMSppAdugsvaAx1pCjweTLGn5Rf"
        let chain = Chain.westend

        let settings = InMemorySettingsManager()
        let walletFactory = WalletPrimitiveFactory(settings: settings)
        let asset = walletFactory.createAssetForAddressType(chain.addressType)

        WebSocketService.shared.setup()
        let connection = WebSocketService.shared.connection!
        let runtimeService = RuntimeRegistryFacade.sharedService
        runtimeService.setup()

        let extrinsicService = ExtrinsicService(
            address: selectedAccount,
            cryptoType: cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )

        let feeExpectation = XCTestExpectation()
        let closure = createExtrinsicBuilderClosure(amount: 10)
        extrinsicService.estimateFee(closure, runningIn: .main) { result in
            switch result {
            case let .success(paymentInfo):
                if
                    let feeValue = BigUInt(paymentInfo.fee),
                    let fee = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision),
                    fee > 0 {
                    feeExpectation.fulfill()
                } else {
                    XCTFail("Cant parse fee")
                }
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
        }

        wait(for: [feeExpectation], timeout: 2)
    }
}
