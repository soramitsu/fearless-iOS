import Foundation
import SoraFoundation

protocol ChangeRewardDestinationViewModelFactoryProtocol {
    func createViewModel(
        from originalRewardDestination: RewardDestination<AccountAddress>,
        selectedRewardDestination: RewardDestination<AccountItem>?,
        bondedAmount: Decimal,
        calculator: RewardCalculatorEngineProtocol,
        nomination: Nomination?,
        priceData: PriceData?
    ) -> ChangeRewardDestinationViewModel?
}

final class ChangeRewardDestinationViewModelFactory {
    let rewardDestinationViewModelFactory: RewardDestinationViewModelFactoryProtocol

    init(rewardDestinationViewModelFactory: RewardDestinationViewModelFactoryProtocol) {
        self.rewardDestinationViewModelFactory = rewardDestinationViewModelFactory
    }

    private func createRewardDestinationViewModelForReward(
        _ reward: CalculatedReward,
        originalRewardDestination: RewardDestination<AccountAddress>,
        selectedRewardDestination: RewardDestination<AccountItem>?,
        priceData: PriceData?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        if let rewardDestination = selectedRewardDestination {
            switch rewardDestination {
            case .restake:
                return rewardDestinationViewModelFactory.createRestake(from: reward, priceData: priceData)
            case let .payout(account):
                return try rewardDestinationViewModelFactory
                    .createPayout(from: reward, priceData: priceData, account: account)
            }
        }

        switch originalRewardDestination {
        case .restake:
            return rewardDestinationViewModelFactory.createRestake(from: reward, priceData: priceData)
        case let .payout(address):
            return try rewardDestinationViewModelFactory
                .createPayout(from: reward, priceData: priceData, address: address)
        }
    }

    private func createRewardDestinationViewModelForValidatorId(
        _ validatorId: AccountId,
        originalRewardDestination: RewardDestination<AccountAddress>,
        selectedRewardDestination: RewardDestination<AccountItem>?,
        bonded: Decimal,
        calculator: RewardCalculatorEngineProtocol,
        priceData: PriceData?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        let restakeReturn = try calculator.calculateValidatorReturn(
            validatorAccountId: validatorId,
            isCompound: true,
            period: .year
        )

        let payoutReturn = try calculator.calculateValidatorReturn(
            validatorAccountId: validatorId,
            isCompound: false,
            period: .year
        )

        let reward = CalculatedReward(
            restakeReturn: restakeReturn * bonded,
            restakeReturnPercentage: restakeReturn,
            payoutReturn: payoutReturn * bonded,
            payoutReturnPercentage: payoutReturn
        )

        return try createRewardDestinationViewModelForReward(
            reward,
            originalRewardDestination: originalRewardDestination,
            selectedRewardDestination: selectedRewardDestination,
            priceData: priceData
        )
    }

    private func createMaxReturnRewardDestinationViewModel(
        for bonded: Decimal,
        originalRewardDestination: RewardDestination<AccountAddress>,
        selectedRewardDestination: RewardDestination<AccountItem>?,
        calculator: RewardCalculatorEngineProtocol,
        priceData: PriceData?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        let restakeReturn = calculator.calculateMaxReturn(isCompound: true, period: .year)

        let payoutReturn = calculator.calculateMaxReturn(isCompound: false, period: .year)

        let reward = CalculatedReward(
            restakeReturn: restakeReturn * bonded,
            restakeReturnPercentage: restakeReturn,
            payoutReturn: payoutReturn * bonded,
            payoutReturnPercentage: payoutReturn
        )

        return try createRewardDestinationViewModelForReward(
            reward, originalRewardDestination: originalRewardDestination,
            selectedRewardDestination: selectedRewardDestination,
            priceData: priceData
        )
    }

    private func createRewardDestinationViewModelFromNomination(
        _ nomination: Nomination,
        originalRewardDestination: RewardDestination<AccountAddress>,
        selectedRewardDestination: RewardDestination<AccountItem>?,
        bonded: Decimal,
        using calculator: RewardCalculatorEngineProtocol,
        priceData: PriceData?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        let (maxTarget, _): (AccountId?, Decimal?) = nomination.targets
            .reduce((nil, nil)) { result, target in
                let targetReturn = try? calculator.calculateValidatorReturn(
                    validatorAccountId: target,
                    isCompound: false,
                    period: .year
                )

                guard let oldReturn = result.1 else {
                    return targetReturn != nil ? (target, targetReturn) : result
                }

                return targetReturn.map { $0 > oldReturn ? (target, $0) : result } ?? result
            }

        if let target = maxTarget {
            return try createRewardDestinationViewModelForValidatorId(
                target,
                originalRewardDestination: originalRewardDestination,
                selectedRewardDestination: selectedRewardDestination,
                bonded: bonded,
                calculator: calculator,
                priceData: priceData
            )
        } else {
            return try createMaxReturnRewardDestinationViewModel(
                for: bonded,
                originalRewardDestination: originalRewardDestination,
                selectedRewardDestination: selectedRewardDestination,
                calculator: calculator,
                priceData: priceData
            )
        }
    }
}

extension ChangeRewardDestinationViewModelFactory: ChangeRewardDestinationViewModelFactoryProtocol {
    func createViewModel(
        from originalRewardDestination: RewardDestination<AccountAddress>,
        selectedRewardDestination: RewardDestination<AccountItem>?,
        bondedAmount: Decimal,
        calculator: RewardCalculatorEngineProtocol,
        nomination: Nomination?,
        priceData: PriceData?
    ) -> ChangeRewardDestinationViewModel? {
        let maybeRewardDestinationViewModel: LocalizableResource<RewardDestinationViewModelProtocol>? = {
            if let nomination = nomination {
                return try? createRewardDestinationViewModelFromNomination(
                    nomination,
                    originalRewardDestination: originalRewardDestination,
                    selectedRewardDestination: selectedRewardDestination,
                    bonded: bondedAmount,
                    using: calculator,
                    priceData: priceData
                )
            }

            return try? createMaxReturnRewardDestinationViewModel(
                for: bondedAmount,
                originalRewardDestination: originalRewardDestination,
                selectedRewardDestination: selectedRewardDestination,
                calculator: calculator,
                priceData: priceData
            )
        }()

        guard let selectionViewModel = maybeRewardDestinationViewModel else {
            return nil
        }

        let alreadyApplied = selectedRewardDestination == nil ||
            (selectedRewardDestination?.accountAddress == originalRewardDestination)

        return ChangeRewardDestinationViewModel(
            selectionViewModel: selectionViewModel,
            canApply: !alreadyApplied
        )
    }
}
