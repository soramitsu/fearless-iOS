// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFAssetManagment
@testable import SSFModels

public class ChainAssetsFetchWorkerProtocolMock: ChainAssetsFetchWorkerProtocol {
public init() {}

    //MARK: - getChainAssetsModels

    public var getChainAssetsModelsCallsCount = 0
    public var getChainAssetsModelsCalled: Bool {
        return getChainAssetsModelsCallsCount > 0
    }
    public var getChainAssetsModelsReturnValue: [ChainAsset]!
    public var getChainAssetsModelsClosure: (() -> [ChainAsset])?

    public func getChainAssetsModels() -> [ChainAsset] {
        getChainAssetsModelsCallsCount += 1
        return getChainAssetsModelsClosure.map({ $0() }) ?? getChainAssetsModelsReturnValue
    }

}
