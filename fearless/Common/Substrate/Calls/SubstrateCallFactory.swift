import Foundation
import FearlessUtils
import IrohaCrypto
import BigInt

protocol SubstrateCallFactoryProtocol {
    func transfer(to receiver: AccountId, amount: BigUInt) -> RuntimeCall<TransferCall>

    func bond(
        amount: BigUInt,
        controller: String,
        rewardDestination: RewardDestination<AccountAddress>
    ) throws -> RuntimeCall<BondCall>

    func bondExtra(amount: BigUInt) -> RuntimeCall<BondExtraCall>

    func unbond(amount: BigUInt) -> RuntimeCall<UnbondCall>

    func rebond(amount: BigUInt) -> RuntimeCall<RebondCall>

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall>

    func payout(validatorId: Data, era: EraIndex) throws -> RuntimeCall<PayoutCall>

    func setPayee(for destination: RewardDestinationArg) -> RuntimeCall<SetPayeeCall>

    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> RuntimeCall<WithdrawUnbondedCall>
}

final class SubstrateCallFactory: SubstrateCallFactoryProtocol {
    private let addressFactory = SS58AddressFactory()

    func bond(
        amount: BigUInt,
        controller: String,
        rewardDestination: RewardDestination<String>
    ) throws -> RuntimeCall<BondCall> {
        let controllerId = try addressFactory.accountId(from: controller)

        let destArg: RewardDestinationArg

        switch rewardDestination {
        case .restake:
            destArg = .staked
        case let .payout(address):
            let accountId = try addressFactory.accountId(from: address)
            destArg = .account(accountId)
        }

        let args = BondCall(
            controller: .accoundId(controllerId),
            value: amount,
            payee: destArg
        )

        return RuntimeCall(moduleName: "Staking", callName: "bond", args: args)
    }

    func bondExtra(amount: BigUInt) -> RuntimeCall<BondExtraCall> {
        let args = BondExtraCall(amount: amount)
        return RuntimeCall(moduleName: "Staking", callName: "bond_extra", args: args)
    }

    func unbond(amount: BigUInt) -> RuntimeCall<UnbondCall> {
        let args = UnbondCall(amount: amount)
        return RuntimeCall(moduleName: "Staking", callName: "unbond", args: args)
    }

    func rebond(amount: BigUInt) -> RuntimeCall<RebondCall> {
        let args = RebondCall(amount: amount)
        return RuntimeCall(moduleName: "Staking", callName: "rebond", args: args)
    }

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall> {
        let addresses: [MultiAddress] = try targets.map { info in
            let accountId = try addressFactory.accountId(from: info.address)
            return MultiAddress.accoundId(accountId)
        }

        let args = NominateCall(targets: addresses)

        return RuntimeCall(moduleName: "Staking", callName: "nominate", args: args)
    }

    func payout(validatorId: Data, era: EraIndex) throws -> RuntimeCall<PayoutCall> {
        let args = PayoutCall(
            validatorStash: validatorId,
            era: era
        )

        return RuntimeCall(moduleName: "Staking", callName: "payout_stakers", args: args)
    }

    func transfer(to receiver: AccountId, amount: BigUInt) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount)
        return RuntimeCall(moduleName: "Balances", callName: "transfer", args: args)
    }

    func setPayee(for destination: RewardDestinationArg) -> RuntimeCall<SetPayeeCall> {
        let args = SetPayeeCall(payee: destination)
        return RuntimeCall(moduleName: "Staking", callName: "set_payee", args: args)
    }

    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> RuntimeCall<WithdrawUnbondedCall> {
        let args = WithdrawUnbondedCall(numberOfSlashingSpans: numberOfSlashingSpans)
        return RuntimeCall(moduleName: "Staking", callName: "withdraw_unbonded", args: args)
    }
}
