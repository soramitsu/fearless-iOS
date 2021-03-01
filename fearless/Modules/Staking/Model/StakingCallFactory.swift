import Foundation
import FearlessUtils
import IrohaCrypto
import BigInt

protocol SubstrateCallFactoryProtocol {
    func bond(amount: BigUInt,
              controller: String,
              rewardDestination: RewardDestination) throws -> RuntimeCall<BondCall>

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall>
}

final class SubstrateCallFactory: SubstrateCallFactoryProtocol {
    private let addressFactory = SS58AddressFactory()

    func bond(amount: BigUInt,
              controller: String,
              rewardDestination: RewardDestination) throws -> RuntimeCall<BondCall> {
        let controllerId = try addressFactory.accountId(from: controller)

        let destArg: RewardDestinationArg

        switch rewardDestination {
        case .restake:
            destArg = .staked
        case .payout(let account):
            let accountId = try addressFactory.accountId(from: account.address)
            destArg = .account(accountId)
        }

        let call = BondCall(controller: .accoundId(controllerId),
                            value: amount,
                            payee: destArg)

        return RuntimeCall<BondCall>.bond(call)
    }

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall> {
        let addresses: [MultiAddress] = try targets.map { info in
            let accountId = try addressFactory.accountId(from: info.address)
            return MultiAddress.accoundId(accountId)
        }

        let call = NominateCall(targets: addresses)

        return RuntimeCall<NominateCall>.nominate(call)
    }
}
