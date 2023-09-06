import Foundation
import BigInt
import SSFUtils
import SSFModels

class SubstrateCallFactoryV9430: SubstrateCallFactoryV9420 {
    override func setController(_: AccountAddress, chainAsset _: ChainAsset) throws -> any RuntimeCallable {
        let path: SubstrateCallPath = .setController
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName
        )
    }

    override func bond(
        amount: BigUInt,
        controller _: String,
        rewardDestination: RewardDestination<String>,
        chainAsset: ChainAsset
    ) throws -> any RuntimeCallable {
        let destArg: RewardDestinationArg

        switch rewardDestination {
        case .restake:
            destArg = .staked
        case let .payout(address):
            let accountId = try AddressFactory.accountId(from: address, chain: chainAsset.chain)
            destArg = .account(accountId)
        }

        let args = BondCallV2(
            value: amount,
            payee: destArg
        )

        let path: SubstrateCallPath = .bond
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }
}
