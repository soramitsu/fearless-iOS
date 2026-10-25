/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Enum is designed to describe possible events
 *  that can occur in data provider.
 */

public enum DataProviderEvent {
    /// Data Provider was created.
    case initialization

    /// Client requested object by identifier
    /// which is passed as associated value.
    case fetchById(_ identifier: String)

    /// Client requested objects from page
    /// which is passed as associated value.
    case fetchPage(_ page: UInt)

    /// An observer was added to data provider
    case addObserver(_ observer: AnyObject)

    /// An observer was removed from data provider.
    case removeObserver(_ observer: AnyObject)
}

/**
 *  Protocol is designed to provide an interface for communication
 *  with trigger.
 *
 *  Implementation of the protocol is responsible for triggering
 *  data provider synchronization based on internal logic.
 */

public protocol DataProviderTriggerProtocol {
    /**
     *  Delegate to notify about triggering based on internal logic.
     */
    var delegate: DataProviderTriggerDelegate? { get set }

    /**
     *  Processes data provider event to update internal state which
     *  can influence triggering.
     *
     *  - parameters:
     *    - event: Data provider event to process.
     */

    func receive(event: DataProviderEvent)
}

/**
 *  Protocol is designed to provide an interface to receive notifications
 *  from data provider trigger.
 */

public protocol DataProviderTriggerDelegate: AnyObject {
    /**
     *  Notifies delegate about triggering.
     */

    func didTrigger()
}

/**
 *  Implementation of the ```DataProviderEventTriggerProtocol``` that triggers
 *  after processing an event from provider subset of data provider's events.
 */

public struct DataProviderEventTrigger: OptionSet {
    public typealias RawValue = UInt8

    /// Never trigger
    public static var onNone: DataProviderEventTrigger { DataProviderEventTrigger(rawValue: 0) }

    /// Trigger after data provider creation
    public static var onInitialization: DataProviderEventTrigger {
        DataProviderEventTrigger(rawValue: 1 << 0)
    }

    /// Trigger after an object request by identifier
    public static var onFetchById: DataProviderEventTrigger {
        DataProviderEventTrigger(rawValue: 1 << 1)
    }

    /// Trigger after a page of objects is requested
    public static var onFetchPage: DataProviderEventTrigger {
        DataProviderEventTrigger(rawValue: 1 << 2)
    }

    /// Trigger after an observer is added to data provider.
    public static var onAddObserver: DataProviderEventTrigger {
        DataProviderEventTrigger(rawValue: 1 << 3)
    }

    /// Trigger after an observer is removed from data provider.
    public static var onRemoveObserver: DataProviderEventTrigger {
        DataProviderEventTrigger(rawValue: 1 << 4)
    }

    /// Trigger after any event.
    public static var onAll: DataProviderEventTrigger {
        let rawValue = DataProviderEventTrigger.onInitialization.rawValue |
            DataProviderEventTrigger.onFetchById.rawValue |
            DataProviderEventTrigger.onFetchPage.rawValue |
            DataProviderEventTrigger.onAddObserver.rawValue |
            DataProviderEventTrigger.onRemoveObserver.rawValue

        return DataProviderEventTrigger(rawValue: rawValue)
    }

    /// Raw representation of the set of events which trigger.
    public private(set) var rawValue: UInt8

    public weak var delegate: DataProviderTriggerDelegate?

    public init(rawValue: DataProviderEventTrigger.RawValue) {
        self.rawValue = rawValue
    }

    public mutating func formIntersection(_ other: DataProviderEventTrigger) {
        rawValue &= other.rawValue
    }

    public mutating func formUnion(_ other: DataProviderEventTrigger) {
        rawValue |= other.rawValue
    }

    public mutating func formSymmetricDifference(_ other: DataProviderEventTrigger) {
        rawValue ^= other.rawValue
    }
}

extension DataProviderEventTrigger: DataProviderTriggerProtocol {
    public func receive(event: DataProviderEvent) {
        guard let delegate = delegate else {
            return
        }

        switch event {
        case .initialization where contains(.onInitialization):
            delegate.didTrigger()
        case .fetchById where contains(.onFetchById):
            delegate.didTrigger()
        case .fetchPage where contains(.onFetchPage):
            delegate.didTrigger()
        case .addObserver where contains(.onAddObserver):
            delegate.didTrigger()
        case .removeObserver where contains(.onRemoveObserver):
            delegate.didTrigger()
        default:
            break
        }
    }
}
