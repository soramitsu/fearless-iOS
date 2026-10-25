// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import RobinHood
@testable import SSFChainConnection
@testable import SSFChainRegistry
@testable import SSFModels
@testable import SSFRuntimeCodingService
@testable import SSFUtils
@testable import SSFXCM

class ChainRegistryProtocolMock: ChainRegistryProtocol {
    // MARK: - getRuntimeProvider

    var getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemThrowableError: Error?
    var getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemCallsCount = 0
    var getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemCalled: Bool {
        getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemCallsCount > 0
    }

    var getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemReceivedArguments: (
        chainId: ChainModel.Id,
        usedRuntimePaths: [String: [String]],
        runtimeItem: RuntimeMetadataItemProtocol?
    )?
    var getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemReceivedInvocations: [(
        chainId: ChainModel.Id,
        usedRuntimePaths: [String: [String]],
        runtimeItem: RuntimeMetadataItemProtocol?
    )] = []
    var getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemReturnValue: RuntimeProviderProtocol!
    var getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemClosure: ((
        ChainModel.Id,
        [String: [String]],
        RuntimeMetadataItemProtocol?
    ) throws -> RuntimeProviderProtocol)?

    func getRuntimeProvider(
        chainId: ChainModel.Id,
        usedRuntimePaths: [String: [String]],
        runtimeItem: RuntimeMetadataItemProtocol?
    ) throws -> RuntimeProviderProtocol {
        if let error = getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemThrowableError {
            throw error
        }
        getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemCallsCount += 1
        getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemReceivedArguments = (
            chainId: chainId,
            usedRuntimePaths: usedRuntimePaths,
            runtimeItem: runtimeItem
        )
        getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemReceivedInvocations.append((
            chainId: chainId,
            usedRuntimePaths: usedRuntimePaths,
            runtimeItem: runtimeItem
        ))
        return try getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemClosure.map { try $0(
            chainId,
            usedRuntimePaths,
            runtimeItem
        ) } ?? getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemReturnValue
    }

    // MARK: - getRuntimeProvider

    var getRuntimeProviderCallsCount = 0
    var getRuntimeProviderCalled: Bool {
        getRuntimeProviderCallsCount > 0
    }

    var getRuntimeProviderReceivedArguments: ChainModel.Id?
    var getRuntimeProviderReceivedInvocations: [ChainModel.Id] = []
    var getRuntimeProviderReturnValue: RuntimeProviderProtocol?
    var getRuntimeProviderClosure: ((ChainModel.Id) -> RuntimeProviderProtocol?)?

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        getRuntimeProviderCallsCount += 1
        getRuntimeProviderReceivedArguments = chainId
        getRuntimeProviderReceivedInvocations.append(chainId)
        return getRuntimeProviderClosure.map { $0(chainId) } ?? getRuntimeProviderReturnValue
    }

    // MARK: - getSubstrateConnection

    var getSubstrateConnectionForThrowableError: Error?
    var getSubstrateConnectionForCallsCount = 0
    var getSubstrateConnectionForCalled: Bool {
        getSubstrateConnectionForCallsCount > 0
    }

    var getSubstrateConnectionForReceivedChain: ChainModel?
    var getSubstrateConnectionForReceivedInvocations: [ChainModel] = []
    var getSubstrateConnectionForReturnValue: SubstrateConnection!
    var getSubstrateConnectionForClosure: ((ChainModel) throws -> SubstrateConnection)?

    func getSubstrateConnection(for chain: ChainModel) throws -> SubstrateConnection {
        if let error = getSubstrateConnectionForThrowableError {
            throw error
        }
        getSubstrateConnectionForCallsCount += 1
        getSubstrateConnectionForReceivedChain = chain
        getSubstrateConnectionForReceivedInvocations.append(chain)
        return try getSubstrateConnectionForClosure
            .map { try $0(chain) } ?? getSubstrateConnectionForReturnValue
    }

    // MARK: - getEthereumConnection

    var getEthereumConnectionForThrowableError: Error?
    var getEthereumConnectionForCallsCount = 0
    var getEthereumConnectionForCalled: Bool {
        getEthereumConnectionForCallsCount > 0
    }

    var getEthereumConnectionForReceivedChain: ChainModel?
    var getEthereumConnectionForReceivedInvocations: [ChainModel] = []
    var getEthereumConnectionForReturnValue: Web3EthConnection!
    var getEthereumConnectionForClosure: ((ChainModel) throws -> Web3EthConnection)?

    func getEthereumConnection(for chain: ChainModel) throws -> Web3EthConnection {
        if let error = getEthereumConnectionForThrowableError {
            throw error
        }
        getEthereumConnectionForCallsCount += 1
        getEthereumConnectionForReceivedChain = chain
        getEthereumConnectionForReceivedInvocations.append(chain)
        return try getEthereumConnectionForClosure
            .map { try $0(chain) } ?? getEthereumConnectionForReturnValue
    }

    // MARK: - getChain

    var getChainForThrowableError: Error?
    var getChainForCallsCount = 0
    var getChainForCalled: Bool {
        getChainForCallsCount > 0
    }

    var getChainForReceivedChainId: ChainModel.Id?
    var getChainForReceivedInvocations: [ChainModel.Id] = []
    var getChainForReturnValue: ChainModel!
    var getChainForClosure: ((ChainModel.Id) throws -> ChainModel)?

    func getChain(for chainId: ChainModel.Id) throws -> ChainModel {
        if let error = getChainForThrowableError {
            throw error
        }
        getChainForCallsCount += 1
        getChainForReceivedChainId = chainId
        getChainForReceivedInvocations.append(chainId)
        return try getChainForClosure.map { try $0(chainId) } ?? getChainForReturnValue
    }

    // MARK: - getChains

    var getChainsThrowableError: Error?
    var getChainsCallsCount = 0
    var getChainsCalled: Bool {
        getChainsCallsCount > 0
    }

    var getChainsReturnValue: [ChainModel]!
    var getChainsClosure: (() throws -> [ChainModel])?

    func getChains() throws -> [ChainModel] {
        if let error = getChainsThrowableError {
            throw error
        }
        getChainsCallsCount += 1
        return try getChainsClosure.map { try $0() } ?? getChainsReturnValue
    }

    // MARK: - getReadySnapshot

    var getReadySnapshotChainIdUsedRuntimePathsRuntimeItemThrowableError: Error?
    var getReadySnapshotChainIdUsedRuntimePathsRuntimeItemCallsCount = 0
    var getReadySnapshotChainIdUsedRuntimePathsRuntimeItemCalled: Bool {
        getReadySnapshotChainIdUsedRuntimePathsRuntimeItemCallsCount > 0
    }

    var getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReceivedArguments: (
        chainId: ChainModel.Id,
        usedRuntimePaths: [String: [String]],
        runtimeItem: RuntimeMetadataItemProtocol?
    )?
    var getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReceivedInvocations: [(
        chainId: ChainModel.Id,
        usedRuntimePaths: [String: [String]],
        runtimeItem: RuntimeMetadataItemProtocol?
    )] = []
    var getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReturnValue: RuntimeSnapshot!
    var getReadySnapshotChainIdUsedRuntimePathsRuntimeItemClosure: ((
        ChainModel.Id,
        [String: [String]],
        RuntimeMetadataItemProtocol?
    ) throws -> RuntimeSnapshot)?

    func getReadySnapshot(
        chainId: ChainModel.Id,
        usedRuntimePaths: [String: [String]],
        runtimeItem: RuntimeMetadataItemProtocol?
    ) throws -> RuntimeSnapshot {
        if let error = getReadySnapshotChainIdUsedRuntimePathsRuntimeItemThrowableError {
            throw error
        }
        getReadySnapshotChainIdUsedRuntimePathsRuntimeItemCallsCount += 1
        getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReceivedArguments = (
            chainId: chainId,
            usedRuntimePaths: usedRuntimePaths,
            runtimeItem: runtimeItem
        )
        getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReceivedInvocations.append((
            chainId: chainId,
            usedRuntimePaths: usedRuntimePaths,
            runtimeItem: runtimeItem
        ))
        return try getReadySnapshotChainIdUsedRuntimePathsRuntimeItemClosure.map { try $0(
            chainId,
            usedRuntimePaths,
            runtimeItem
        ) } ?? getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReturnValue
    }
}
