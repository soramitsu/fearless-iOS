import Foundation
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
import XCTest
@testable import fearless

final class CovGSubstrateCallFactoryTests: XCTestCase {
    private let account = Data(repeating: 7, count: 32)
    private var factory: SubstrateCallFactoryDefault {
        SubstrateCallFactoryDefault(runtimeService: CovGHistoryRuntime())
    }

    func testAmountCallsEncodeExpectedPathsAndValues() throws {
        let calls: [(any RuntimeCallable, String, String, String, String)] = [
            (factory.bondExtra(amount: 123), "Staking", "bond_extra", "max_additional", "123"),
            (factory.unbond(amount: 124), "Staking", "unbond", "value", "124"),
            (factory.rebond(amount: 125), "Staking", "rebond", "value", "125"),
            (factory.withdrawUnbonded(for: 3), "Staking", "withdraw_unbonded", "num_slashing_spans", "3"),
            (factory.joinPool(poolId: "9", amount: 126), "NominationPools", "join", "amount", "126"),
            (factory.poolUnbond(accountId: account, amount: 127), "NominationPools", "unbond", "unbondingPoints", "127"),
            (factory.poolUnbondOld(accountId: account, amount: 128), "NominationPools", "unbond", "unbondingPoints", "128"),
            (factory.poolWithdrawUnbonded(accountId: account, numSlashingSpans: 4), "NominationPools", "withdraw_unbonded", "numSlashingSpans", "4")
        ]
        for (call, module, name, key, value) in calls {
            XCTAssertEqual(try arguments(call, module: module, name: name)[key] as? String, value)
        }
        let bond = try arguments(factory.poolBondMore(amount: 18), module: "NominationPools", name: "bond_extra")
        XCTAssertEqual(bond["extra"] as? [String], ["FreeBalance", "18"])
        XCTAssertEqual(try arguments(factory.joinPool(poolId: "9", amount: 1), module: "NominationPools", name: "join")["poolId"] as? String, "9")
    }

    func testPayoutAndNoArgumentCalls() throws {
        let payout = try arguments(factory.payout(validatorId: account, era: 8, page: nil), module: "Staking", name: "payout_stakers")
        XCTAssertEqual(payout["era"] as? String, "8")
        XCTAssertEqual(payout["validator_stash"] as? String, account.base64EncodedString())
        XCTAssertTrue(try arguments(factory.chill(), module: "Staking", name: "chill").isEmpty)
        XCTAssertTrue(try arguments(factory.claimPoolRewards(), module: "NominationPools", name: "claim_payout").isEmpty)
        XCTAssertThrowsError(try factory.payout(validatorId: account, era: 8, page: 1))
    }

    func testCrowdloanAndMetadataCallsPreserveInputBytes() throws {
        let contribute = try arguments(factory.contribute(to: 42, amount: 99), module: "Crowdloan", name: "contribute")
        XCTAssertEqual(contribute["index"] as? String, "42")
        XCTAssertEqual(contribute["value"] as? String, "99")
        XCTAssertTrue(contribute["signature"] is NSNull)
        let memo = try XCTUnwrap(factory.addMemo(to: 42, memo: account) as? RuntimeCall<CrowdloanAddMemo>)
        XCTAssertEqual(memo.args.memo, account)
        XCTAssertEqual(memo.args.index, 42)
        let remark = try XCTUnwrap(factory.addRemark(account) as? RuntimeCall<AddRemarkCall>)
        XCTAssertEqual(remark.args.remark, account)
        XCTAssertEqual(remark.callName, "remark")
        let metadata = try arguments(factory.setPoolMetadata(poolId: "8", metadata: account), module: "NominationPools", name: "set_metadata")
        XCTAssertEqual(metadata["poolId"] as? String, "8")
        XCTAssertEqual(metadata["metadata"] as? String, account.base64EncodedString())
    }

    func testTransferRoutingKeepsAmountDestinationAndCurrency() throws {
        let routes: [(SubstrateAssetType, String)] = [
            (.normal, "Balances"), (.ormlChain, "Tokens"), (.ormlAsset, "Currencies"), (.foreignAsset, "Currencies"),
            (.stableAssetPoolToken, "Currencies"), (.liquidCrowdloan, "Currencies"), (.vToken, "Currencies"), (.vsToken, "Currencies"),
            (.stable, "Currencies"), (.assetId, "Currencies"), (.token2, "Currencies"), (.xcm, "Currencies"),
            (.equilibrium, "EqBalances"), (.soraAsset, "Assets"), (.assets, "Assets")
        ]
        for (type, module) in routes {
            let asset = AssetModel(id: "asset", name: "Asset", symbol: "UNIT", precision: 12, currencyId: "1", isUtility: false, isNative: false, type: type)
            let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: asset)
            let call = try XCTUnwrap(factory.transfer(to: account, amount: 777, chainAsset: chainAsset) as? RuntimeCall<TransferCall>)
            XCTAssertEqual(call.moduleName, module)
            XCTAssertEqual(call.callName, "transfer")
            XCTAssertEqual(call.args.value, 777)
            if type == .equilibrium {
                if case let .accountTo(value) = call.args.dest {
                    XCTAssertEqual(value, account)
                } else {
                    XCTFail("Expected account destination")
                }
            } else if case let .accoundId(value) = call.args.dest {
                XCTAssertEqual(value, account)
            } else {
                XCTFail("Expected multi-address destination")
            }
        }
        let keepAlive = try XCTUnwrap(factory.transfer(to: account, amount: 5) as? RuntimeCall<TransferCall>)
        XCTAssertEqual(keepAlive.callName, "transfer")
        XCTAssertEqual(keepAlive.args.value, 5)
    }

    func testNominationAndControllerCallsUseDecodedAccountIds() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let address = try account.toAddress(using: .substrate(42))
        let validators = [SelectedValidatorInfo(address: address)]
        let nominate = try XCTUnwrap(factory.nominate(targets: validators, chainAsset: chainAsset) as? RuntimeCall<NominateCall>)
        XCTAssertEqual(nominate.moduleName, "Staking")
        XCTAssertEqual(nominate.args.targets.count, 1)
        if case let .accoundId(value) = nominate.args.targets[0] {
            XCTAssertEqual(value, account)
        } else {
            XCTFail("Wrong target")
        }
        let pool = try XCTUnwrap(factory.poolNominate(poolId: 7, targets: validators) as? RuntimeCall<PoolNominateCall>)
        XCTAssertEqual(pool.args.validators, [account])
        XCTAssertEqual(pool.args.pool_id, "7")
        let controller = try XCTUnwrap(factory.setController(address, chainAsset: chainAsset) as? RuntimeCall<SetControllerCall>)
        if case let .accoundId(value) = controller.args.controller {
            XCTAssertEqual(value, account)
        } else {
            XCTFail("Wrong controller")
        }
        XCTAssertThrowsError(try factory.nominate(targets: [.init(address: "invalid")], chainAsset: chainAsset))
    }

    func testRewardDestinationUsesRestakeStashControllerAndExplicitAccount() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let address = try account.toAddress(using: .substrate(42))
        let stash = StashItem(stash: "stash", controller: "controller")
        let cases: [(RewardDestination<String>, RewardDestinationArg)] = [
            (.restake, .staked), (.payout(account: "stash"), .stash), (.payout(account: "controller"), .controller),
            (.payout(account: address), .account(account))
        ]
        for (destination, expected) in cases {
            let call = try XCTUnwrap(factory.setRewardDestination(destination, stashItem: stash, chainAsset: chainAsset) as? RuntimeCall<SetPayeeCall>)
            XCTAssertEqual(call.args.payee, expected)
            XCTAssertEqual(call.callName, "set_payee")
        }
    }

    func testRoleUpdatesEncodeSetAndRemoveForEachRole() throws {
        for setRoles in [true, false] {
            let roles = StakingPoolRoles(depositor: account, root: setRoles ? account : nil, nominator: setRoles ? account : nil, bouncer: setRoles ? account : nil)
            let args = try arguments(factory.nominationPoolUpdateRoles(poolId: "3", roles: roles), module: "NominationPools", name: "update_roles")
            XCTAssertEqual(args["poolId"] as? String, "3")
            for key in ["newRoot", "newNominator", "newBouncer"] {
                let value = try XCTUnwrap(args[key] as? [String])
                XCTAssertEqual(value, setRoles ? ["Set", account.base64EncodedString()] : ["Remove"])
            }
        }
    }

    func testMetadataDependentCallsFailWithoutSnapshot() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        XCTAssertThrowsError(try factory.bond(amount: 1, controller: "invalid", rewardDestination: .restake, chainAsset: chainAsset))
        XCTAssertThrowsError(try factory.createPool(amount: 1, root: .accoundId(account), nominator: .accoundId(account), bouncer: .accoundId(account)))
        XCTAssertThrowsError(try factory.vestingClaim())
    }

    func testModernRuntimeBondOmitsControllerAndPayoutIncludesPage() throws {
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let factory = SubstrateCallFactoryDefault(runtimeService: runtime)
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let address = try account.toAddress(using: .substrate(42))
        for destination in [RewardDestination<String>.restake, .payout(account: address)] {
            let call = try XCTUnwrap(factory.bond(amount: 99, controller: address, rewardDestination: destination, chainAsset: chainAsset) as? RuntimeCall<BondCall>)
            XCTAssertNil(call.args.controller)
            XCTAssertEqual(call.args.value, 99)
            XCTAssertEqual(call.args.payee, destination == .restake ? .staked : .account(account))
        }
        let payout = try arguments(factory.payout(validatorId: account, era: 8, page: 2), module: "Staking", name: "payout_stakers_by_page")
        XCTAssertEqual(payout["page"] as? String, "2")
        let transfer = factory.defaultTransfer(to: account, amount: 1)
        XCTAssertEqual(transfer.callName, "transfer_allow_death")
        let controller = try factory.setController(address, chainAsset: chainAsset)
        XCTAssertEqual(controller.callName, "set_controller")
        let pool = try arguments(
            factory.createPool(amount: 44, root: .accoundId(account), nominator: .accoundId(account), bouncer: .accoundId(account)),
            module: "NominationPools",
            name: "create"
        )
        XCTAssertEqual(pool["amount"] as? String, "44")
        XCTAssertNotNil(pool["bouncer"])
        let vest = try factory.vestingClaim()
        XCTAssertEqual(vest.moduleName, "Vesting")
        XCTAssertEqual(vest.callName, "vest")
    }

    private func arguments(_ call: any RuntimeCallable, module: String, name: String) throws -> [String: Any] {
        XCTAssertEqual(call.moduleName, module)
        XCTAssertEqual(call.callName, name)
        let value = try JSONSerialization.jsonObject(with: JSONEncoder().encode(call))
        let outer = try XCTUnwrap(value as? [Any])
        let inner = try XCTUnwrap(outer[1] as? [Any])
        return try XCTUnwrap(inner[1] as? [String: Any])
    }
}
