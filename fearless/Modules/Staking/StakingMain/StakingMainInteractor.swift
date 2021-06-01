import Foundation
import SoraKeystore
import RobinHood
import FearlessUtils
import SoraFoundation

final class StakingMainInteractor: RuntimeConstantFetching {
    weak var presenter: StakingMainInteractorOutputProtocol!

    let providerFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let settings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let calculatorService: RewardCalculatorServiceProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let operationManager: OperationManagerProtocol
    let primitiveFactory: WalletPrimitiveFactoryProtocol
    let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let logger: LoggerProtocol

    var priceProvider: AnySingleValueProvider<PriceData>?
    var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    var stashControllerProvider: StreamableProvider<StashItem>?
    var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
    var validatorProvider: AnyDataProvider<DecodedValidator>?
    var nominatorProvider: AnyDataProvider<DecodedNomination>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    var totalRewardProvider: AnySingleValueProvider<TotalRewardItem>?
    var payeeProvider: AnyDataProvider<DecodedPayee>?
    var controllerAccountProvider: StreamableProvider<AccountItem>?

    var currentAccount: AccountItem?
    var currentConnection: ConnectionItem?

    init(
        providerFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        settings: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol,
        primitiveFactory: WalletPrimitiveFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        calculatorService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        logger: Logger
    ) {
        self.providerFactory = providerFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.accountRepositoryFactory = accountRepositoryFactory
        self.settings = settings
        self.eventCenter = eventCenter
        self.primitiveFactory = primitiveFactory
        self.eraValidatorService = eraValidatorService
        self.calculatorService = calculatorService
        self.runtimeService = runtimeService
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.eraInfoOperationFactory = eraInfoOperationFactory
        self.applicationHandler = applicationHandler
        self.logger = logger
    }

    func provideSelectedAccount() {
        guard let address = currentAccount?.address else {
            return
        }

        presenter.didReceive(selectedAddress: address)
    }

    func provideMaxNominatorsPerValidator() {
        fetchConstant(
            for: .maxNominatorRewardedPerValidator,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveMaxNominatorsPerValidator(result: result)
        }
    }

    func provideNewChain() {
        guard let chain = currentConnection?.type.chain else {
            return
        }

        presenter.didReceive(newChain: chain)
    }

    func provideRewardCalculator() {
        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceive(calculator: engine)
                } catch {
                    self?.presenter.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(
            operations: [operation],
            in: .transient
        )
    }

    func provideEraStakersInfo() {
        let operation = eraValidatorService.fetchInfoOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let info = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceive(eraStakersInfo: info)
                } catch {
                    self?.presenter.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(
            operations: [operation],
            in: .transient
        )
    }

    func provideNetworkStakingInfo() {
        let wrapper = eraInfoOperationFactory.networkStakingOperation()

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(networkStakingInfo: info)
                } catch {
                    self?.presenter.didReceive(networkStakingInfoError: error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}
