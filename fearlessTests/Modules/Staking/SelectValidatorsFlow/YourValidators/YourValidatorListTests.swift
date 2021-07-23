import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import Cuckoo
import IrohaCrypto
import SoraFoundation

class YourValidatorListTests: XCTestCase {

    func testSetupCompletesAndActiveValidatorReceived() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let chain = Chain.westend

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: chain,
                                                            keychain: keychain,
                                                            settings: settings)

        let storageFacade = SubstrateStorageTestFacade()
        let operationManager = OperationManager()

        let view = MockYourValidatorListViewProtocol()
        let wireframe = MockYourValidatorListWireframeProtocol()

        // prepare nomination and corresponding validators

        let nominatorAddress = settings.selectedAccount!.address
        let activeValidators = WestendStub.activeValidators(for: nominatorAddress)

        let addressFactory = SS58AddressFactory()
        let targets = try activeValidators.map { validator in
            try addressFactory.accountId(from: validator.address)
        }

        let nomination = Nomination(targets: targets,
                                    submittedIn: WestendStub.activeEra.item!.index - 1
        )

        let expectedValidatorAddresses = Set(activeValidators.map { $0.address })

        let singleValueProviderFactory = SingleValueProviderFactoryStub
            .westendNominatorStub()
            .with(nomination: nomination, for: nominatorAddress)

        // save stash item
        
        let stashItem = StashItem(stash: nominatorAddress, controller: nominatorAddress)
        let repository: CoreDataRepository<StashItem, CDStashItem> =
            storageFacade.createRepository()

        let saveStashItemOperation = repository.saveOperation({ [stashItem] }, { [] })
        OperationQueue().addOperations([saveStashItemOperation], waitUntilFinished: true)

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager
        )

        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService()
        let eraValidatorService = EraValidatorServiceStub.westendStub()

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageTestFacade().createRepository()
        let anyAccountRepository = AnyDataProviderRepository(accountRepository)

        let validatorOperationFactory = MockValidatorOperationFactoryProtocol()

        stub(validatorOperationFactory) { stub in
            when(stub).allSelectedOperation(by: any(), nominatorAddress: any()).then { _ in
                CompoundOperationWrapper.createWithResult(activeValidators)
            }

            when(stub).pendingValidatorsOperation(for: any()).then { _ in
                CompoundOperationWrapper.createWithResult([])
            }

            when(stub).activeValidatorsOperation(for: any()).then { _ in
                CompoundOperationWrapper.createWithResult(activeValidators)
            }
        }

        let interactor = YourValidatorListInteractor(
            chain: chain,
            providerFactory: singleValueProviderFactory,
            substrateProviderFactory: substrateProviderFactory,
            settings: settings,
            accountRepository: anyAccountRepository,
            runtimeService: runtimeCodingService,
            eraValidatorService: eraValidatorService,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: operationManager
        )

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let viewModelFactory = YourValidatorListViewModelFactory(
            balanceViewModeFactory: balanceViewModelFactory
        )

        let presenter = YourValidatorListPresenter(interactor: interactor,
                                                wireframe: wireframe,
                                                viewModelFactory: viewModelFactory,
                                                chain: chain,
                                                localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter
        presenter.view = view

        let expectation = XCTestExpectation()

        var receivedValidatorAddresses: Set<AccountAddress>?

        stub(view) { stub in
            when(stub).reload(state: any()).then { state in
                if case .validatorList(let viewModel) = state, !viewModel.sections.isEmpty {
                    receivedValidatorAddresses = viewModel.sections
                        .flatMap { $0.validators }
                        .reduce(into: Set<AccountAddress>()) { $0.insert($1.address) }
                    expectation.fulfill()
                }
            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual(expectedValidatorAddresses, receivedValidatorAddresses)
    }
}
