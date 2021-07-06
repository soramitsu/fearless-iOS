import XCTest
@testable import fearless
import SoraKeystore
import Cuckoo
import RobinHood
import IrohaCrypto
import SoraFoundation
import BigInt

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

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let viewModelFacade = StakingViewModelFacade(primitiveFactory: primitiveFactory)
        let stateViewModelFactory = StakingStateViewModelFactory(primitiveFactory: primitiveFactory,
                                                                 logger: Logger.shared)
        let networkViewModelFactory = NetworkInfoViewModelFactory(primitiveFactory: primitiveFactory)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = StakingMainPresenter(stateViewModelFactory: stateViewModelFactory,
                                             networkInfoViewModelFactory: networkViewModelFactory,
                                             viewModelFacade: viewModelFacade,
                                             dataValidatingFactory: dataValidatingFactory,
                                             logger: Logger.shared)

        let substrateProviderFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                                    operationManager: operationManager)

        let operationFactory = MockNetworkStakingInfoOperationFactoryProtocol()

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageTestFacade().createRepository()
        let anyAccountRepository = AnyDataProviderRepository(accountRepository)

        let accountRepositoryFactory = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let interactor = StakingMainInteractor(providerFactory: providerFactory,
                                               substrateProviderFactory: substrateProviderFactory,
                                               accountRepositoryFactory: accountRepositoryFactory,
                                               settings: settings,
                                               eventCenter: eventCenter,
                                               primitiveFactory: primitiveFactory,
                                               eraValidatorService: eraValidatorService,
                                               calculatorService: calculatorService,
                                               runtimeService: runtimeCodingService,
                                               accountRepository: anyAccountRepository,
                                               operationManager: operationManager,
                                               eraInfoOperationFactory: operationFactory,
                                               applicationHandler: ApplicationHandler(),
                                               logger: Logger.shared)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        // when

        let accountExpectation = XCTestExpectation()
        let nominatorStateExpectation = XCTestExpectation()
        let chainExpectation = XCTestExpectation()
        let networkStakingInfoExpectation = XCTestExpectation()
        let networkStakingInfoExpandedExpectation = XCTestExpectation()

        stub(operationFactory) { stub in
            when(stub).networkStakingOperation().then { _ in
                CompoundOperationWrapper.createWithResult(
                    NetworkStakingInfo(
                        totalStake: BigUInt.zero,
                        minStakeAmongActiveNominators: BigUInt.zero,
                        minimalBalance: BigUInt.zero,
                        activeNominatorsCount: 0,
                        lockUpPeriod: 0
                    )
                )
            }
        }

        stub(view) { stub in
            stub.didReceive(viewModel: any()).then { _ in
                accountExpectation.fulfill()
            }

            stub.didReceiveChainName(chainName: any()).then { _ in
                chainExpectation.fulfill()
            }

            stub.didRecieveNetworkStakingInfo(viewModel: any()).then { _ in
                networkStakingInfoExpectation.fulfill()
            }

            stub.didReceiveStakingState(viewModel: any()).then { state in
                if case .nominator = state {
                    nominatorStateExpectation.fulfill()
                }
            }
            stub.expandNetworkInfoView(any()).then { _ in
                networkStakingInfoExpandedExpectation.fulfill()
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
            chainExpectation,
            networkStakingInfoExpectation,
            networkStakingInfoExpandedExpectation
        ]

        wait(for: expectations, timeout: 5)
    }

    func testManageStakingBalanceAction() {
        // given

        let options: [StakingManageOption] = [
            .stakingBalance,
            .rewardPayouts,
            .changeValidators(count: 16)
        ]

        let wireframe = MockStakingMainWireframeProtocol()

        let showStakingBalanceExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showStakingBalance(from: any()).then { _ in
                showStakingBalanceExpectation.fulfill()
            }
        }

        // when

        let presenter = performStakingManageTestSetup(for: wireframe)

        presenter.modalPickerDidSelectModelAtIndex(0, context: options as NSArray)

        // then
        wait(for: [showStakingBalanceExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testManageStakingValidatorsAction() {
        // given

        let options: [StakingManageOption] = [
            .stakingBalance,
            .rewardPayouts,
            .changeValidators(count: 16)
        ]

        let wireframe = MockStakingMainWireframeProtocol()

        let showValidatorsExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showNominatorValidators(from: any()).then { _ in
                showValidatorsExpectation.fulfill()
            }
        }

        // when

        let presenter = performStakingManageTestSetup(for: wireframe)

        presenter.modalPickerDidSelectModelAtIndex(2, context: options as NSArray)

        // then
        wait(for: [showValidatorsExpectation], timeout: Constants.defaultExpectationDuration)
    }

    private func performStakingManageTestSetup(
        for wireframe: StakingMainWireframeProtocol
    ) -> StakingMainPresenter {
        let interactor = StakingMainInteractorInputProtocolStub()

        let settings = InMemorySettingsManager()
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let viewModelFacade = StakingViewModelFacade(primitiveFactory: primitiveFactory)
        let stateViewModelFactory = StakingStateViewModelFactory(
            primitiveFactory: primitiveFactory,
            logger: nil
        )
        let networkViewModelFactory = NetworkInfoViewModelFactory(primitiveFactory: primitiveFactory)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingMainPresenter(
            stateViewModelFactory: stateViewModelFactory,
            networkInfoViewModelFactory: networkViewModelFactory,
            viewModelFacade: viewModelFacade,
            dataValidatingFactory: dataValidatingFactory,
            logger: nil
        )

        presenter.wireframe = wireframe
        presenter.interactor = interactor

        presenter.didReceive(newChain: .westend)
        presenter.didReceive(stashItem: StashItem(stash: WestendStub.address, controller: WestendStub.address))
        presenter.didReceive(ledgerInfo: WestendStub.ledgerInfo.item)
        presenter.didReceive(nomination: WestendStub.nomination.item)

        return presenter
    }
}
