import XCTest
@testable import fearless
import SoraKeystore
import IrohaCrypto
import RobinHood
import BigInt
import Cuckoo
import SoraFoundation

class SelectValidatorsConfirmTests: XCTestCase {
    let initiatedBoding: PreparedNomination<InitiatedBonding> = {
        let validator1 = SelectedValidatorInfo(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
                                               identity: nil)
        let validator2 = SelectedValidatorInfo(address: "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq",
                                               identity: nil)
        let initiatedBonding = InitiatedBonding(amount: 1.0, rewardDestination: .restake)

        return PreparedNomination(bonding: initiatedBonding,
                                  targets: [validator1, validator2],
                                  maxTargets: 16)
    }()

    func testSetupAndSendExtrinsic() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let addressType = SNAddressType.genericSubstrate
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            keychain: keychain,
                                                            settings: settings)

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            XCTFail("Invalid asset id")
            return
        }

        let view = MockSelectValidatorsConfirmViewProtocol()
        let wireframe = MockSelectValidatorsConfirmWireframeProtocol()

        let confirmViewModelFactory = SelectValidatorsConfirmViewModelFactory()
        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: addressType,
                                                              limit: StakingConstants.maxAmount)

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let signer = try DummySigner(cryptoType: .sr25519)

        let extrinsicService = ExtrinsicServiceStub.dummy()

        guard let selectedAccount = settings.selectedAccount else {
            XCTFail("Invalid account address")
            return
        }

        let singleValueProviderFactory = SingleValueProviderFactoryStub.westendNominatorStub()
        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService()

        let interactor =
            InitiatedBondingConfirmInteractor(selectedAccount: selectedAccount,
                                              selectedConnection: settings.selectedConnection,
                                              singleValueProviderFactory: singleValueProviderFactory,
                                              extrinsicService: extrinsicService,
                                              runtimeService: runtimeCodingService,
                                              durationOperationFactory: StakingDurationOperationFactory(),
                                              operationManager: OperationManager(),
                                              signer: signer,
                                              assetId: assetId,
                                              nomination: initiatedBoding)

        let presenter = SelectValidatorsConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmationViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            asset:asset
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

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

            when(stub).localizationManager.get.thenReturn(LocalizationManager.shared)

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
