import UIKit
import SoraKeystore
import RobinHood

final class YourValidatorsInteractor {
    weak var presenter: YourValidatorsInteractorOutputProtocol!

    let providerFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let settings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let calculatorService: RewardCalculatorServiceProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let operationManager: OperationManagerProtocol

    var stashControllerProvider: StreamableProvider<StashItem>?
    var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
    var nominatorProvider: AnyDataProvider<DecodedNomination>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?

    init(
        providerFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        settings: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        calculatorService: RewardCalculatorServiceProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.providerFactory = providerFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.settings = settings
        self.eventCenter = eventCenter
        self.runtimeService = runtimeService
        self.calculatorService = calculatorService
        self.eraValidatorService = eraValidatorService
        self.operationManager = operationManager
    }
}

extension YourValidatorsInteractor: YourValidatorsInteractorInputProtocol {
    func setup() {}
}
