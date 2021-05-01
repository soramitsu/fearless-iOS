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

    func bondExtra(amount: BigUInt) throws -> RuntimeCall<BondExtraCall>

    func unbond(amount: BigUInt) -> RuntimeCall<UnbondCall>

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall>

    func payout(validatorId: Data, era: EraIndex) throws -> RuntimeCall<PayoutCall>
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

        return RuntimeCall<BondCall>(moduleName: "Staking", callName: "bond", args: args)
    }

    func bondExtra(amount: BigUInt) throws -> RuntimeCall<BondExtraCall> {
        let args = BondExtraCall(amount: amount)
        return RuntimeCall<BondExtraCall>(moduleName: "Staking", callName: "bond_extra", args: args)
    }

    func unbond(amount: BigUInt) -> RuntimeCall<UnbondCall> {
        let args = UnbondCall(amount: amount)
        return RuntimeCall<UnbondCall>(moduleName: "Staking", callName: "unbond", args: args)
    }

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall> {
        let addresses: [MultiAddress] = try targets.map { info in
            let accountId = try addressFactory.accountId(from: info.address)
            return MultiAddress.accoundId(accountId)
        }

        let args = NominateCall(targets: addresses)

        return RuntimeCall<NominateCall>(moduleName: "Staking", callName: "nominate", args: args)
    }

    func payout(validatorId: Data, era: EraIndex) throws -> RuntimeCall<PayoutCall> {
        let args = PayoutCall(
            validatorStash: validatorId,
            era: era
        )

        return RuntimeCall<PayoutCall>(moduleName: "Staking", callName: "payout_stakers", args: args)
    }

    func transfer(to receiver: AccountId, amount: BigUInt) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount)
        return RuntimeCall<TransferCall>(moduleName: "Balances", callName: "transfer", args: args)
    }
}
