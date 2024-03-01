import Foundation
import RobinHood

protocol ValidatorOperationFactoryProtocol {
    func nomination(accountId: AccountId) -> CompoundOperationWrapper<Nomination?>

    func fetchAllValidators(staked: Decimal) -> CompoundOperationWrapper<[ElectedValidatorInfo]>
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]>
    func allSelectedOperation(
        by nomination: Nomination,
        nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>

    func activeValidatorsOperation(
        for nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>

    func pendingValidatorsOperation(
        for accountIds: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>

    func wannabeValidatorsOperation(
        for accountIdList: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>
}
