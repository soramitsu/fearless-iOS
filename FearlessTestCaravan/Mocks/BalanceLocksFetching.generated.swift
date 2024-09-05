// Generated using Sourcery 2.2.5 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
import SSFModels
@testable import fearless

public class BalanceLocksFetchingMock: BalanceLocksFetching {
public init() {}

    //MARK: - fetchStakingLocks

    public var fetchStakingLocksForThrowableError: Error?
    public var fetchStakingLocksForCallsCount = 0
    public var fetchStakingLocksForCalled: Bool {
        return fetchStakingLocksForCallsCount > 0
    }
    public var fetchStakingLocksForReceivedAccountId: AccountId?
    public var fetchStakingLocksForReceivedInvocations: [AccountId] = []
    public var fetchStakingLocksForReturnValue: StakingLocks!
    public var fetchStakingLocksForClosure: ((AccountId) throws -> StakingLocks)?

    public func fetchStakingLocks(for accountId: AccountId) throws -> StakingLocks {
        if let error = fetchStakingLocksForThrowableError {
            throw error
        }
        fetchStakingLocksForCallsCount += 1
        fetchStakingLocksForReceivedAccountId = accountId
        fetchStakingLocksForReceivedInvocations.append(accountId)
        return try fetchStakingLocksForClosure.map({ try $0(accountId) }) ?? fetchStakingLocksForReturnValue
    }

    //MARK: - fetchNominationPoolLocks

    public var fetchNominationPoolLocksForThrowableError: Error?
    public var fetchNominationPoolLocksForCallsCount = 0
    public var fetchNominationPoolLocksForCalled: Bool {
        return fetchNominationPoolLocksForCallsCount > 0
    }
    public var fetchNominationPoolLocksForReceivedAccountId: AccountId?
    public var fetchNominationPoolLocksForReceivedInvocations: [AccountId] = []
    public var fetchNominationPoolLocksForReturnValue: StakingLocks!
    public var fetchNominationPoolLocksForClosure: ((AccountId) throws -> StakingLocks)?

    public func fetchNominationPoolLocks(for accountId: AccountId) throws -> StakingLocks {
        if let error = fetchNominationPoolLocksForThrowableError {
            throw error
        }
        fetchNominationPoolLocksForCallsCount += 1
        fetchNominationPoolLocksForReceivedAccountId = accountId
        fetchNominationPoolLocksForReceivedInvocations.append(accountId)
        return try fetchNominationPoolLocksForClosure.map({ try $0(accountId) }) ?? fetchNominationPoolLocksForReturnValue
    }

    //MARK: - fetchGovernanceLocks

    public var fetchGovernanceLocksForThrowableError: Error?
    public var fetchGovernanceLocksForCallsCount = 0
    public var fetchGovernanceLocksForCalled: Bool {
        return fetchGovernanceLocksForCallsCount > 0
    }
    public var fetchGovernanceLocksForReceivedAccountId: AccountId?
    public var fetchGovernanceLocksForReceivedInvocations: [AccountId] = []
    public var fetchGovernanceLocksForReturnValue: Decimal!
    public var fetchGovernanceLocksForClosure: ((AccountId) throws -> Decimal)?

    public func fetchGovernanceLocks(for accountId: AccountId) throws -> Decimal {
        if let error = fetchGovernanceLocksForThrowableError {
            throw error
        }
        fetchGovernanceLocksForCallsCount += 1
        fetchGovernanceLocksForReceivedAccountId = accountId
        fetchGovernanceLocksForReceivedInvocations.append(accountId)
        return try fetchGovernanceLocksForClosure.map({ try $0(accountId) }) ?? fetchGovernanceLocksForReturnValue
    }

    //MARK: - fetchCrowdloanLocks

    public var fetchCrowdloanLocksForThrowableError: Error?
    public var fetchCrowdloanLocksForCallsCount = 0
    public var fetchCrowdloanLocksForCalled: Bool {
        return fetchCrowdloanLocksForCallsCount > 0
    }
    public var fetchCrowdloanLocksForReceivedAccountId: AccountId?
    public var fetchCrowdloanLocksForReceivedInvocations: [AccountId] = []
    public var fetchCrowdloanLocksForReturnValue: Decimal!
    public var fetchCrowdloanLocksForClosure: ((AccountId) throws -> Decimal)?

    public func fetchCrowdloanLocks(for accountId: AccountId) throws -> Decimal {
        if let error = fetchCrowdloanLocksForThrowableError {
            throw error
        }
        fetchCrowdloanLocksForCallsCount += 1
        fetchCrowdloanLocksForReceivedAccountId = accountId
        fetchCrowdloanLocksForReceivedInvocations.append(accountId)
        return try fetchCrowdloanLocksForClosure.map({ try $0(accountId) }) ?? fetchCrowdloanLocksForReturnValue
    }

    //MARK: - fetchVestingLocks

    public var fetchVestingLocksForCurrencyIdThrowableError: Error?
    public var fetchVestingLocksForCurrencyIdCallsCount = 0
    public var fetchVestingLocksForCurrencyIdCalled: Bool {
        return fetchVestingLocksForCurrencyIdCallsCount > 0
    }
    public var fetchVestingLocksForCurrencyIdReceivedArguments: (accountId: AccountId, currencyId: CurrencyId?)?
    public var fetchVestingLocksForCurrencyIdReceivedInvocations: [(accountId: AccountId, currencyId: CurrencyId?)] = []
    public var fetchVestingLocksForCurrencyIdReturnValue: Decimal!
    public var fetchVestingLocksForCurrencyIdClosure: ((AccountId, CurrencyId?) throws -> Decimal)?

    public func fetchVestingLocks(for accountId: AccountId, currencyId: CurrencyId?) throws -> Decimal {
        if let error = fetchVestingLocksForCurrencyIdThrowableError {
            throw error
        }
        fetchVestingLocksForCurrencyIdCallsCount += 1
        fetchVestingLocksForCurrencyIdReceivedArguments = (accountId: accountId, currencyId: currencyId)
        fetchVestingLocksForCurrencyIdReceivedInvocations.append((accountId: accountId, currencyId: currencyId))
        return try fetchVestingLocksForCurrencyIdClosure.map({ try $0(accountId, currencyId) }) ?? fetchVestingLocksForCurrencyIdReturnValue
    }

    //MARK: - fetchTotalLocks

    public var fetchTotalLocksForCurrencyIdThrowableError: Error?
    public var fetchTotalLocksForCurrencyIdCallsCount = 0
    public var fetchTotalLocksForCurrencyIdCalled: Bool {
        return fetchTotalLocksForCurrencyIdCallsCount > 0
    }
    public var fetchTotalLocksForCurrencyIdReceivedArguments: (accountId: AccountId, currencyId: CurrencyId?)?
    public var fetchTotalLocksForCurrencyIdReceivedInvocations: [(accountId: AccountId, currencyId: CurrencyId?)] = []
    public var fetchTotalLocksForCurrencyIdReturnValue: Decimal!
    public var fetchTotalLocksForCurrencyIdClosure: ((AccountId, CurrencyId?) throws -> Decimal)?

    public func fetchTotalLocks(for accountId: AccountId, currencyId: CurrencyId?) throws -> Decimal {
        if let error = fetchTotalLocksForCurrencyIdThrowableError {
            throw error
        }
        fetchTotalLocksForCurrencyIdCallsCount += 1
        fetchTotalLocksForCurrencyIdReceivedArguments = (accountId: accountId, currencyId: currencyId)
        fetchTotalLocksForCurrencyIdReceivedInvocations.append((accountId: accountId, currencyId: currencyId))
        return try fetchTotalLocksForCurrencyIdClosure.map({ try $0(accountId, currencyId) }) ?? fetchTotalLocksForCurrencyIdReturnValue
    }

    //MARK: - fetchAssetLocks

    public var fetchAssetLocksForCurrencyIdThrowableError: Error?
    public var fetchAssetLocksForCurrencyIdCallsCount = 0
    public var fetchAssetLocksForCurrencyIdCalled: Bool {
        return fetchAssetLocksForCurrencyIdCallsCount > 0
    }
    public var fetchAssetLocksForCurrencyIdReceivedArguments: (accountId: AccountId, currencyId: CurrencyId?)?
    public var fetchAssetLocksForCurrencyIdReceivedInvocations: [(accountId: AccountId, currencyId: CurrencyId?)] = []
    public var fetchAssetLocksForCurrencyIdReturnValue: Decimal!
    public var fetchAssetLocksForCurrencyIdClosure: ((AccountId, CurrencyId?) throws -> Decimal)?

    public func fetchAssetLocks(for accountId: AccountId, currencyId: CurrencyId?) throws -> Decimal {
        if let error = fetchAssetLocksForCurrencyIdThrowableError {
            throw error
        }
        fetchAssetLocksForCurrencyIdCallsCount += 1
        fetchAssetLocksForCurrencyIdReceivedArguments = (accountId: accountId, currencyId: currencyId)
        fetchAssetLocksForCurrencyIdReceivedInvocations.append((accountId: accountId, currencyId: currencyId))
        return try fetchAssetLocksForCurrencyIdClosure.map({ try $0(accountId, currencyId) }) ?? fetchAssetLocksForCurrencyIdReturnValue
    }

    //MARK: - fetchAssetFrozen

    public var fetchAssetFrozenForCurrencyIdThrowableError: Error?
    public var fetchAssetFrozenForCurrencyIdCallsCount = 0
    public var fetchAssetFrozenForCurrencyIdCalled: Bool {
        return fetchAssetFrozenForCurrencyIdCallsCount > 0
    }
    public var fetchAssetFrozenForCurrencyIdReceivedArguments: (accountId: AccountId, currencyId: CurrencyId?)?
    public var fetchAssetFrozenForCurrencyIdReceivedInvocations: [(accountId: AccountId, currencyId: CurrencyId?)] = []
    public var fetchAssetFrozenForCurrencyIdReturnValue: Decimal!
    public var fetchAssetFrozenForCurrencyIdClosure: ((AccountId, CurrencyId?) throws -> Decimal)?

    public func fetchAssetFrozen(for accountId: AccountId, currencyId: CurrencyId?) throws -> Decimal {
        if let error = fetchAssetFrozenForCurrencyIdThrowableError {
            throw error
        }
        fetchAssetFrozenForCurrencyIdCallsCount += 1
        fetchAssetFrozenForCurrencyIdReceivedArguments = (accountId: accountId, currencyId: currencyId)
        fetchAssetFrozenForCurrencyIdReceivedInvocations.append((accountId: accountId, currencyId: currencyId))
        return try fetchAssetFrozenForCurrencyIdClosure.map({ try $0(accountId, currencyId) }) ?? fetchAssetFrozenForCurrencyIdReturnValue
    }

    //MARK: - fetchAssetBlocked

    public var fetchAssetBlockedForCurrencyIdThrowableError: Error?
    public var fetchAssetBlockedForCurrencyIdCallsCount = 0
    public var fetchAssetBlockedForCurrencyIdCalled: Bool {
        return fetchAssetBlockedForCurrencyIdCallsCount > 0
    }
    public var fetchAssetBlockedForCurrencyIdReceivedArguments: (accountId: AccountId, currencyId: CurrencyId?)?
    public var fetchAssetBlockedForCurrencyIdReceivedInvocations: [(accountId: AccountId, currencyId: CurrencyId?)] = []
    public var fetchAssetBlockedForCurrencyIdReturnValue: Decimal!
    public var fetchAssetBlockedForCurrencyIdClosure: ((AccountId, CurrencyId?) throws -> Decimal)?

    public func fetchAssetBlocked(for accountId: AccountId, currencyId: CurrencyId?) throws -> Decimal {
        if let error = fetchAssetBlockedForCurrencyIdThrowableError {
            throw error
        }
        fetchAssetBlockedForCurrencyIdCallsCount += 1
        fetchAssetBlockedForCurrencyIdReceivedArguments = (accountId: accountId, currencyId: currencyId)
        fetchAssetBlockedForCurrencyIdReceivedInvocations.append((accountId: accountId, currencyId: currencyId))
        return try fetchAssetBlockedForCurrencyIdClosure.map({ try $0(accountId, currencyId) }) ?? fetchAssetBlockedForCurrencyIdReturnValue
    }

}
