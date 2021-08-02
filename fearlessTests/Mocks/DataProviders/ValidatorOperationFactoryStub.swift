@testable import fearless
import RobinHood

class ValidatorOperationFactoryStub: ValidatorOperationFactoryProtocol {
    private let electedValidatorList: [ElectedValidatorInfo]
    private let selectedValidatorList: [SelectedValidatorInfo]

    init(
        electedValidatorList: [ElectedValidatorInfo] = [],
        selectedValidatorList: [SelectedValidatorInfo] = []
    ) {
        self.electedValidatorList = electedValidatorList
        self.selectedValidatorList = selectedValidatorList
    }

    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        CompoundOperationWrapper.createWithResult(electedValidatorList)
    }

    func allSelectedOperation(by nomination: Nomination, nominatorAddress: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CompoundOperationWrapper.createWithResult(selectedValidatorList)
    }

    func activeValidatorsOperation(for nominatorAddress: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CompoundOperationWrapper.createWithResult(selectedValidatorList)
    }

    func pendingValidatorsOperation(for accountIds: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CompoundOperationWrapper.createWithResult(selectedValidatorList)
    }

    func wannabeValidatorsOperation(for accountIdList: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CompoundOperationWrapper.createWithResult(selectedValidatorList)
    }
}
