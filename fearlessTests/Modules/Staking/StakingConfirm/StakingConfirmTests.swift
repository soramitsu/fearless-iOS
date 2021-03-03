import XCTest
@testable import fearless
import SoraKeystore
import IrohaCrypto
import RobinHood
import BigInt
import Cuckoo

class StakingConfirmTests: XCTestCase {
    let state: PreparedNomination = {
        let validator1 = SelectedValidatorInfo(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
                                               identity: nil)
        let validator2 = SelectedValidatorInfo(address: "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq",
                                               identity: nil)
        return PreparedNomination(amount: 1.0,
                                  rewardDestination: .restake,
                                  targets: [validator1, validator2])
    }()

    let price: PriceData = {
        PriceData(price: "0.3",
                  time: Int64(Date().timeIntervalSince1970),
                  height: 1,
                  records: [])
    }()

    let accountInfo: DecodedAccountInfo = {


        let data = DyAccountData(free: BigUInt(1e+13),
                                 reserved: BigUInt(0),
                                 miscFrozen: BigUInt(0),
                                 feeFrozen: BigUInt(0))

        let info = DyAccountInfo(nonce: 1,
                                 consumers: 0,
                                 providers: 0,
                                 data: data)

        return DecodedAccountInfo(identifier: "5EJQtTE1ZS9cBdqiuUcjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
                                  item: info)
    }()

    func testSetupAndSendExtrinsic() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let addressType = SNAddressType.kusamaMain
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            keychain: keychain,
                                                            settings: settings)

        let primitiveFactory = WalletPrimitiveFactory(keystore: keychain, settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        let view = MockStakingConfirmViewProtocol()
        let wireframe = MockStakingConfirmWireframeProtocol()

        let confirmViewModelFactory = StakingConfirmViewModelFactory(asset: asset)
        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: addressType,
                                                              limit: StakingConstants.maxAmount)
        let presenter = StakingConfirmPresenter(state: state,
                                                asset: asset,
                                                walletAccount: settings.selectedAccount!,
                                                confirmationViewModelFactory: confirmViewModelFactory,
                                                balanceViewModelFactory: balanceViewModelFactory)

        let signer = try DummySigner(cryptoType: .sr25519)

        let priceProvider = SingleValueProviderStub(item: price)
        let balanceProvider = DataProviderStub(models: [accountInfo])
        let extrinsicService = ExtrinsicServiceStub.dummy()
        let interactor = StakingConfirmInteractor(priceProvider: AnySingleValueProvider(priceProvider),
                                                  balanceProvider: AnyDataProvider(balanceProvider),
                                                  extrinsicService: extrinsicService,
                                                  operationManager: OperationManager(),
                                                  signer: signer)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
        let confirmExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(feeViewModel: any()).then { viewModel in
                if viewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didReceive(assetViewModel: any()).then { _ in
                assetExpectation.fulfill()
            }

            when(stub).didReceive(confirmationViewModel: any()).then { _ in
                confirmExpectation.fulfill()
            }

            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).complete(from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [feeExpectation, assetExpectation, confirmExpectation],
             timeout: Constants.defaultExpectationDuration)

        // when

        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
