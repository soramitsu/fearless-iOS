import Foundation
import SoraFoundation
import SSFModels

protocol ChangeRewardDestinationViewModelFactoryProtocol {
    func createViewModel(
        from originalRewardDestination: RewardDestination<AccountAddress>,
        selectedRewardDestination: RewardDestination<ChainAccountResponse>?,
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
        selectedRewardDestination: RewardDestination<ChainAccountResponse>?,
        priceData: PriceData?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        if let rewardDestination = selectedRewardDestination {
            switch rewardDestination {
            case .restake:
                return rewardDestinationViewModelFactory.createRestake(from: reward, priceData: priceData)
            case let .payout(account):
                return try rewardDestinationViewModelFactory
                    .createPayout(from: reward, priceData: priceData, address: account.toDisplayAddress().address, title: account.toDisplayAddress().username)
            }
        }

        switch originalRewardDestination {
        case .restake:
            return rewardDestinationViewModelFactory.createRestake(from: reward, priceData: priceData)
        case let .payout(address):
            return try rewardDestinationViewModelFactory
                .createPayout(from: reward, priceData: priceData, address: address, title: address)
        }
    }

    private func createRewardDestinationViewModelForValidatorId(
        _ validatorId: AccountId,
        originalRewardDestination: RewardDestination<AccountAddress>,
        selectedRewardDestination: RewardDestination<ChainAccountResponse>?,
        bonded: Decimal,
        calculator: RewardCalculatorEngineProtocol,
        priceData: PriceData?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        let restakeReturn = calculator.calculatorReturn(isCompound: true, period: .year, type: .max(validatorId))
        let payoutReturn = calculator.calculatorReturn(isCompound: false, period: .year, type: .max(validatorId))
        let restakeEarnings = try calculator.calculateEarnings(amount: bonded, validatorAccountId: validatorId, isCompound: true, period: .year)
        let payoutEarnings = try calculator.calculateEarnings(amount: bonded, validatorAccountId: validatorId, isCompound: false, period: .year)

        let reward = CalculatedReward(
            restakeReturn: restakeEarnings,
            restakeReturnPercentage: restakeReturn,
            payoutReturn: payoutEarnings,
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
        selectedRewardDestination: RewardDestination<ChainAccountResponse>?,
        calculator: RewardCalculatorEngineProtocol,
        priceData: PriceData?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        let restakeReturn = calculator.calculatorReturn(isCompound: true, period: .year, type: .max())

        let payoutReturn = calculator.calculatorReturn(isCompound: false, period: .year, type: .max())

        let restakeEarnings = calculator.calculateMaxEarnings(amount: bonded, isCompound: true, period: .year)
        let payoutEarnings = calculator.calculateMaxEarnings(amount: bonded, isCompound: false, period: .year)

        let reward = CalculatedReward(
            restakeReturn: restakeEarnings,
            restakeReturnPercentage: restakeReturn,
            payoutReturn: payoutEarnings,
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
        selectedRewardDestination: RewardDestination<ChainAccountResponse>?,
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
        selectedRewardDestination: RewardDestination<ChainAccountResponse>?,
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
