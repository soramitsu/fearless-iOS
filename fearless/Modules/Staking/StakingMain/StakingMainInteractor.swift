import Foundation
import SoraKeystore
import RobinHood
import FearlessUtils

final class StakingMainInteractor {
    weak var presenter: StakingMainInteractorOutputProtocol!

    let providerFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let settings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let calculatorService: RewardCalculatorServiceProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let operationManager: OperationManagerProtocol
    let primitiveFactory: WalletPrimitiveFactoryProtocol
    let logger: LoggerProtocol

    var priceProvider: AnySingleValueProvider<PriceData>?
    var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    var stashControllerProvider: StreamableProvider<StashItem>?
    var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
    var validatorProvider: AnyDataProvider<DecodedValidator>?
    var nominatorProvider: AnyDataProvider<DecodedNomination>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?

    var currentAccount: AccountItem?
    var currentConnection: ConnectionItem?

    init(providerFactory: SingleValueProviderFactoryProtocol,
         substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
         settings: SettingsManagerProtocol,
         eventCenter: EventCenterProtocol,
         primitiveFactory: WalletPrimitiveFactoryProtocol,
         eraValidatorService: EraValidatorServiceProtocol,
         calculatorService: RewardCalculatorServiceProtocol,
         runtimeService: RuntimeCodingServiceProtocol,
         operationManager: OperationManagerProtocol,
         logger: Logger) {
        self.providerFactory = providerFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.settings = settings
        self.eventCenter = eventCenter
        self.primitiveFactory = primitiveFactory
        self.eraValidatorService = eraValidatorService
        self.calculatorService = calculatorService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.logger = logger
    }

    func provideSelectedAccount() {
        guard let address = currentAccount?.address else {
            return
        }

        presenter.didReceive(selectedAddress: address)
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

        operationManager.enqueue(operations: [operation],
                                 in: .transient)
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

        operationManager.enqueue(operations: [operation],
                                 in: .transient)
    }

    func provideLockupPeriod() {
        let factoryOperation = runtimeService.fetchCoderFactoryOperation()

        let lockUpPeriodOperation = PrimitiveConstantOperation<UInt32>(path: .lockUpPeriodInEras)
        lockUpPeriodOperation.configurationBlock = {
            do {
                lockUpPeriodOperation.codingFactory = try factoryOperation.extractNoCancellableResultData()
            } catch {
                lockUpPeriodOperation.result = .failure(error)
            }
        }

        lockUpPeriodOperation.addDependency(factoryOperation)

        lockUpPeriodOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let value = try lockUpPeriodOperation.extractNoCancellableResultData()
                    self?.presenter.didRecieve(lockUpPeriod: value)
                } catch {
                    self?.presenter.didRecieve(lockUpPeriodError: error)
                }
            }
        }

        operationManager.enqueue(operations: [factoryOperation, lockUpPeriodOperation],
                                 in: .transient)
    }
}
