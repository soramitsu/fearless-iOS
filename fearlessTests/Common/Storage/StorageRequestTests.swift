import XCTest
@testable import fearless
import SSFModels
import SSFStorageQueryKit

final class StorageRequestTests: XCTestCase {
    func testSimpleRequestsUseExpectedStoragePaths() {
        XCTAssertEqual(SystemNumberRequest().storagePath, .blockNumber)
        assertSimpleWorkerType(SystemNumberRequest().parametersType.workerType)

        XCTAssertEqual(StakingCurrentEraRequest().storagePath, .currentEra)
        assertSimpleWorkerType(StakingCurrentEraRequest().parametersType.workerType)
    }

    func testAccountBasedRequestsEncodeTheAccountId() {
        let accountId = Data(repeating: 0x01, count: 32)

        assertEncodable(StakingControllerRequest(accountId: accountId).parametersType, equals: accountId)
        XCTAssertEqual(StakingControllerRequest(accountId: accountId).storagePath, .controller)

        assertEncodable(StakingLedgerRequest(accountId: accountId).parametersType, equals: accountId)
        XCTAssertEqual(StakingLedgerRequest(accountId: accountId).storagePath, .stakingLedger)

        assertEncodable(BalancesLocksRequest(accountId: accountId).parametersType, equals: accountId)
        XCTAssertEqual(BalancesLocksRequest(accountId: accountId).storagePath, .balanceLocks)
    }

    func testNominationPoolsMembersRequestUsesPoolMembersPath() {
        let accountId = Data(repeating: 0x02, count: 32)
        let request = NominationPoolsPoolMembersRequest(accountId: accountId)

        assertEncodable(request.parametersType, equals: accountId)
        XCTAssertEqual(request.storagePath, .stakingPoolMembers)
    }

    func testNMapRequestsPreserveExpectedKeyOrder() {
        let accountId = Data(repeating: 0x03, count: 32)
        let currencyId: SSFModels.CurrencyId = .assetId(id: "1984")

        let assetsByAccountId = AssetsAccountRequest(accountId: accountId, currencyId: currencyId)
        let tokensByAccountId = TokensLocksRequest(accountId: accountId, currencyId: currencyId)

        assertNMap(assetsByAccountId.parametersType) { params in
            XCTAssertEqual(params.count, 2)
            XCTAssertCurrencyId(params[0][0], equals: currencyId)
            XCTAssertParam(params[1][0], equals: accountId)
        }
        XCTAssertEqual(assetsByAccountId.storagePath, .assetsAccount)

        assertNMap(tokensByAccountId.parametersType) { params in
            XCTAssertEqual(params.count, 2)
            XCTAssertParam(params[0][0], equals: accountId)
            XCTAssertCurrencyId(params[1][0], equals: currencyId)
        }
        XCTAssertEqual(tokensByAccountId.storagePath, .tokensLocks)
    }

    func testSystemAccountRequestSwitchesBetweenMapAndNMapAccess() {
        let accountId = Data(repeating: 0x04, count: 32)

        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        let plainAsset = ChainModelGenerator.generateAssetWithId("plain", symbol: "PLN")
        let utilityChainAsset = ChainAsset(chain: chain, asset: plainAsset)

        let plainRequest = SystemAccountRequest(accountId: accountId, chainAsset: utilityChainAsset)
        assertEncodable(plainRequest.parametersType, equals: accountId)
        XCTAssertEqual(plainRequest.storagePath, .account)

        let assetWithCurrencyId = SSFModels.AssetModel(
            id: "asset-with-currency-id",
            name: "Asset",
            symbol: "AST",
            precision: 12,
            icon: nil,
            currencyId: "42",
            existentialDeposit: nil,
            color: nil,
            isUtility: false,
            isNative: false,
            staking: nil,
            purchaseProviders: nil,
            type: .assetId,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
        let chainAsset = ChainAsset(chain: chain, asset: assetWithCurrencyId)

        let accountIdRequest = SystemAccountRequest(accountId: accountId, chainAsset: chainAsset)
        assertNMap(accountIdRequest.parametersType) { params in
            XCTAssertEqual(params.count, 2)
            XCTAssertParam(params[0][0], equals: accountId)
            XCTAssertCurrencyId(params[1][0], equals: .assetId(id: "42"))
        }
    }

    func testPrefixRequestsPointToExpectedStakingStorageEntries() {
        let rewardPoints = StakingErasRewardPointsRequest()
        assertStoragePath(
            rewardPoints.storagePath,
            equals: fearless.StorageCodingPath.erasRewardPoints
        )
        assertU32KeyType(rewardPoints.keyType)
        assertSimplePrefixParameters(rewardPoints.parametersType)

        let totalStake = StakingErasTotalStakeRequest()
        assertStoragePath(
            totalStake.storagePath,
            equals: fearless.StorageCodingPath.erasTotalStake
        )
        assertU32KeyType(totalStake.keyType)
        assertSimplePrefixParameters(totalStake.parametersType)

        let validatorReward = StakingErasValidatorRewardRequest()
        assertStoragePath(
            validatorReward.storagePath,
            equals: fearless.StorageCodingPath.erasValidatorReward
        )
        assertU32KeyType(validatorReward.keyType)
        assertSimplePrefixParameters(validatorReward.parametersType)
    }

    private func assertEncodable<T: Equatable & Encodable>(
        _ parametersType: fearless.StorageRequestParametersType,
        equals expected: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .encodable(param) = parametersType else {
            XCTFail("Expected encodable parameters", file: file, line: line)
            return
        }

        guard let value = param as? T else {
            XCTFail("Unexpected parameter type: \(type(of: param))", file: file, line: line)
            return
        }

        XCTAssertEqual(value, expected, file: file, line: line)
    }

    private func assertNMap(
        _ parametersType: fearless.StorageRequestParametersType,
        file: StaticString = #filePath,
        line: UInt = #line,
        assertions: ([[any fearless.NMapKeyParamProtocol]]) -> Void
    ) {
        guard case let .nMap(params) = parametersType else {
            XCTFail("Expected nMap parameters", file: file, line: line)
            return
        }

        assertions(params)
    }

    private func XCTAssertParam<T: Equatable & Encodable>(
        _ param: any fearless.NMapKeyParamProtocol,
        equals expected: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let typedParam = param as? fearless.NMapKeyParam<T> else {
            XCTFail("Unexpected key param type: \(type(of: param))", file: file, line: line)
            return
        }

        XCTAssertEqual(typedParam.value, expected, file: file, line: line)
    }

    private func XCTAssertCurrencyId(
        _ param: any fearless.NMapKeyParamProtocol,
        equals expected: SSFModels.CurrencyId,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let typedParam = param as? fearless.NMapKeyParam<SSFModels.CurrencyId> else {
            XCTFail("Unexpected currency param type: \(type(of: param))", file: file, line: line)
            return
        }

        switch (typedParam.value, expected) {
        case let (.assetId(id: lhs), .assetId(id: rhs)):
            XCTAssertEqual(lhs, rhs, file: file, line: line)
        default:
            XCTFail("Unexpected currency id values", file: file, line: line)
        }
    }

    private func assertSimpleWorkerType(
        _ workerType: fearless.StorageRequestWorkerType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .simple = workerType else {
            XCTFail("Expected simple worker type", file: file, line: line)
            return
        }
    }

    private func assertSimplePrefixParameters(
        _ parametersType: SSFStorageQueryKit.PrefixStorageRequestParametersType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .simple = parametersType else {
            XCTFail("Expected simple prefix parameters", file: file, line: line)
            return
        }
    }

    private func assertU32KeyType(
        _ keyType: SSFStorageQueryKit.MapKeyType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .u32 = keyType else {
            XCTFail("Expected u32 key type", file: file, line: line)
            return
        }
    }

    private func assertStoragePath(
        _ storagePath: any SSFModels.StorageCodingPathProtocol,
        equals expected: fearless.StorageCodingPath,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(storagePath.moduleName, expected.moduleName, file: file, line: line)
        XCTAssertEqual(storagePath.itemName, expected.itemName, file: file, line: line)
    }
}
