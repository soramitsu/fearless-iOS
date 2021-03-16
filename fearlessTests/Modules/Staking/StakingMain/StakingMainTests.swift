import XCTest
@testable import fearless
import SoraKeystore
import Cuckoo
import RobinHood

class StakingMainTests: XCTestCase {
    func testSuccessfullSetup() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: .westend,
                                                            keychain: keychain,
                                                            settings: settings)

        let eventCenter = MockEventCenterProtocol().applyingDefaultStub()

        let operationManager = OperationManager()

        let view = MockStakingMainViewProtocol()
        let wireframe = MockStakingMainWireframeProtocol()

        let providerFactory = SingleValueProviderFactoryStub.westendStub()

        let calculatorService = RewardCalculatorServiceStub(engine: WestendStub.rewardCalculator)
        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService()

        let primitiveFactory = WalletPrimitiveFactory(keystore: keychain,
                                                      settings: settings)
        let viewModelFacade = StakingViewModelFacade(primitiveFactory: primitiveFactory)
        let presenter = StakingMainPresenter(viewModelFacade: viewModelFacade,
                                             logger: Logger.shared)

        let substrateProviderFactory = SubstrateDataProviderFactory(facade: SubstrateStorageTestFacade(),
                                                                    operationManager: operationManager)
        let interactor = StakingMainInteractor(providerFactory: providerFactory,
                                               substrateProviderFactory: substrateProviderFactory,
                                               settings: settings,
                                               eventCenter: eventCenter,
                                               primitiveFactory: primitiveFactory,
                                               calculatorService: calculatorService,
                                               runtimeService: runtimeCodingService,
                                               operationManager: operationManager,
                                               logger: Logger.shared)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        let accountExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
        let chainExpectation = XCTestExpectation()

        // reloads on: balance change, price change, new chain
        assetExpectation.expectedFulfillmentCount = 3

        let inputExpectation = XCTestExpectation()

        let rewardExpectation = XCTestExpectation()

        // reloads on: calculator change, price change, new chain
        rewardExpectation.expectedFulfillmentCount = 3

        stub(view) { stub in
            stub.didReceive(viewModel: any()).then { _ in
                accountExpectation.fulfill()
            }

            stub.didReceiveAsset(viewModel: any()).then { _ in
                assetExpectation.fulfill()
            }

            stub.didReceiveInput(viewModel: any()).then { _ in
                inputExpectation.fulfill()
            }

            stub.didReceiveRewards(monthlyViewModel: any(), yearlyViewModel: any()).then { _ in
                rewardExpectation.fulfill()
            }

            stub.didReceiveChainName(chainName: any()).then { _ in
                chainExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        let expectations = [
            accountExpectation,
            assetExpectation,
            inputExpectation,
            rewardExpectation,
            chainExpectation
        ]

        wait(for: expectations, timeout: Constants.defaultExpectationDuration)
    }
}
