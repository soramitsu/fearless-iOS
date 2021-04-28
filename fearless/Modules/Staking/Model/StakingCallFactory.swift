import Foundation
import FearlessUtils
import IrohaCrypto
import BigInt

protocol SubstrateCallFactoryProtocol {
    func bond(
        amount: BigUInt,
        controller: String,
        rewardDestination: RewardDestination<AccountAddress>
    ) throws -> RuntimeCall<BondCall>
    func bondExtra(amount: BigUInt) throws -> RuntimeCall<BondExtraCall>

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

        let call = BondCall(
            controller: .accoundId(controllerId),
            value: amount,
            payee: destArg
        )

        return RuntimeCall<BondCall>.bond(call)
    }

    func bondExtra(amount: BigUInt) throws -> RuntimeCall<BondExtraCall> {
        let call = BondExtraCall(amount: amount)
        return RuntimeCall<BondExtraCall>.bondExtra(call)
    }

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall> {
        let addresses: [MultiAddress] = try targets.map { info in
            let accountId = try addressFactory.accountId(from: info.address)
            return MultiAddress.accoundId(accountId)
        }

        let call = NominateCall(targets: addresses)

        return RuntimeCall<NominateCall>.nominate(call)
    }

    func payout(validatorId: Data, era: EraIndex) throws -> RuntimeCall<PayoutCall> {
        let call = PayoutCall(
            validatorStash: validatorId,
            era: era
        )

        return RuntimeCall<PayoutCall>.payout(call)
    }
}
