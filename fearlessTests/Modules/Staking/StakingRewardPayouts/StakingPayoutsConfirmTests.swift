import XCTest
@testable import fearless
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import RobinHood
import Cuckoo

class StakingPayoutsConfirmTests: XCTestCase {
    func testSetupAndSendExtrinsic() throws {
        // given

        let address = "5E9W1jho79KwmnwxnGjGaBEyWw9XFjhu3upEaDtwWSvVgbou"
        let validatorAccountId = try! SS58AddressFactory().accountId(from: address)

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let chain: Chain = .westend

        let storageFacade = SubstrateStorageTestFacade()
        let operationManager = OperationManager()

        let addressType = chain.addressType
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            keychain: keychain,
                                                            settings: settings)

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)
        let assetId = WalletAssetId(
            rawValue: asset.identifier
        )!

        let view = MockStakingPayoutConfirmationViewProtocol()
        let wireframe = MockStakingPayoutConfirmationWireframeProtocol()

        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: addressType,
                                                              limit: StakingConstants.maxAmount)

        let viewModelFactory = StakingPayoutConfirmViewModelFactory(asset: asset,
                                                                    balanceViewModelFactory: balanceViewModelFactory)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = StakingPayoutConfirmationPresenter(balanceViewModelFactory: balanceViewModelFactory,
                                                           payoutConfirmViewModelFactory: viewModelFactory,
                                                           dataValidatingFactory: dataValidatingFactory,
                                                           chain: chain,
                                                           asset: asset,
                                                           logger: nil)

        let extrinsicService = ExtrinsicServiceStub.dummy()
        let signer = try DummySigner(cryptoType: .sr25519)

        let providerFactory = SingleValueProviderFactoryStub.westendNominatorStub()

        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService()

        let substrateProviderFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                                    operationManager: operationManager)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageTestFacade().createRepository()

        let extrinsicOperationFactory = ExtrinsicOperationFactoryStub()

        let interactor = StakingPayoutConfirmationInteractor(
            singleValueProviderFactory: providerFactory,
            substrateProviderFactory: substrateProviderFactory,
            extrinsicOperationFactory: extrinsicOperationFactory,
            extrinsicService: extrinsicService,
            runtimeService: runtimeCodingService,
            signer: signer,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationManager: OperationManager(),
            logger: Logger.shared,
            selectedAccount: settings.selectedAccount!,
            payouts: [PayoutInfo(era: 1000, validator: validatorAccountId, reward: 1, identity: nil)],
            chain: chain,
            assetId: assetId
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let viewModelExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(feeViewModel: any()).then { viewModel in
                if viewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didRecieve(viewModel: any()).then {_ in
                viewModelExpectation.fulfill()
            }

            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()

            when(stub).localizationManager.get.then { LocalizationManager.shared }
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).complete(from: any()).then { _ in
                completionExpectation.fulfill()
            }

            when(stub).present(
                message: any(),
                title: any(),
                closeAction: any(),
                from: any()).thenDoNothing()
        }

        // when

        presenter.setup()

        // then

        wait(for: [feeExpectation, viewModelExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
