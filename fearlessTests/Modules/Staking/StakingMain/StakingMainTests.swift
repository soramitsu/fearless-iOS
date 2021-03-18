import XCTest
@testable import fearless
import SoraKeystore
import Cuckoo
import RobinHood
import IrohaCrypto

class StakingMainTests: XCTestCase {
    func testNominatorStateSetup() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: .westend,
                                                            keychain: keychain,
                                                            settings: settings)

        let storageFacade = SubstrateStorageTestFacade()
        let operationManager = OperationManager()

        let eventCenter = MockEventCenterProtocol().applyingDefaultStub()

        let view = MockStakingMainViewProtocol()
        let wireframe = MockStakingMainWireframeProtocol()

        let providerFactory = SingleValueProviderFactoryStub.westendNominatorStub()

        let calculatorService = RewardCalculatorServiceStub(engine: WestendStub.rewardCalculator)
        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService()
        let eraValidatorService = EraValidatorServiceStub.westendStub()

        let primitiveFactory = WalletPrimitiveFactory(keystore: keychain,
                                                      settings: settings)
        let viewModelFacade = StakingViewModelFacade(primitiveFactory: primitiveFactory)
        let stateViewModelFactory = StakingStateViewModelFactory(primitiveFactory: primitiveFactory,
                                                                 logger: Logger.shared)
        let presenter = StakingMainPresenter(stateViewModelFactory: stateViewModelFactory,
                                             viewModelFacade: viewModelFacade,
                                             logger: Logger.shared)

        let substrateProviderFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                                    operationManager: operationManager)
        let interactor = StakingMainInteractor(providerFactory: providerFactory,
                                               substrateProviderFactory: substrateProviderFactory,
                                               settings: settings,
                                               eventCenter: eventCenter,
                                               primitiveFactory: primitiveFactory,
                                               eraValidatorService: eraValidatorService,
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
        let nominatorStateExpectation = XCTestExpectation()
        let chainExpectation = XCTestExpectation()


        stub(view) { stub in
            stub.didReceive(viewModel: any()).then { _ in
                accountExpectation.fulfill()
            }

            stub.didReceiveChainName(chainName: any()).then { _ in
                chainExpectation.fulfill()
            }

            stub.didReceiveStakingState(viewModel: any()).then { state in
                if case .nominator = state {
                    nominatorStateExpectation.fulfill()
                }
            }
        }

        presenter.setup()

        // prepare and save stash account and that should allow to resolve state to nominator by state machine

        let stashAccountId = WestendStub.ledgerInfo.item!.stash
        let stash = try SS58AddressFactory().addressFromAccountId(data: stashAccountId,
                                                                  type: .genericSubstrate)
        let controller = settings.selectedAccount!.address
        let stashItem = StashItem(stash: stash, controller: controller)

        let repository: CoreDataRepository<StashItem, CDStashItem> = storageFacade.createRepository()
        let saveStashItemOperation = repository.saveOperation( { [stashItem] }, { [] })

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            operationManager.enqueue(operations: [saveStashItemOperation], in: .transient)
        }

        // then

        let expectations = [
            accountExpectation,
            nominatorStateExpectation,
            chainExpectation
        ]

        wait(for: expectations, timeout: 5)
    }
}
