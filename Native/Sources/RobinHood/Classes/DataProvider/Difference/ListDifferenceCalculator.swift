/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Enum is designed to define type of changes in the list of objects.
 */

public enum ListDifference<Model> {
    /// An object at given index was replaced with new one.
    /// An index, old and new objects are passed as associated values.
    case update(index: Int, old: Model, new: Model)

    /// An object at given index was deleted.
    /// An index and old object are passed as associated values.
    case delete(index: Int, old: Model)

    /// New object at given index was inserted
    /// An index and new object are passed as associated value.
    case insert(index: Int, new: Model)
}

/**
 *  Protocol is designed to provide an interface for difference calculation between
 *  two lists.
 *
 *  Implementation of the protocol should find how current list will change
 *  when changes described as a list of ```DataProviderChange``` items are applied and
 *  return list of ```ListDifference``` items as a result. List of last difference can be
 *  accessed via ```lastDifferences``` property. Changes in the ```lastDifferences``` are sorted
 *  by type first: update, delete, insert. Inside groups delete changes are sorted
 *  desc by index and insert change asc. Update changes are not sorted.
 *  Also the client doesn't need to store list of objects separately
 *  as it should be available via ```allItems``` property.
 */

public protocol ListDifferenceCalculatorProtocol {
    associatedtype Model: Identifiable

    /// Defines sortition closure of difference calculator. See ```sortBlock``` property.
    typealias ListDifferenceSortBlock = (Model, Model) -> Bool

    /**
      *  Maximum number of objects that the calculator must maintain. If this value
      *  is zero than no constraints are applied.
      *
      *  - note: For objects which are exlicitly removed due to the constraint
      *    corresponding diff events must be generated.
     */

    var limit: Int { get set }

    /**
     *  Current objects list.
     *
     *  The property should always be modified after ```apply(changes:)``` call.
     */

    var allItems: [Model] { get }

    /**
     *  Last calculated changes.
     *
     *  The property should always be modified after ```apply(changes:)``` call.
     */
    var lastDifferences: [ListDifference<Model>] { get }

    /**
     *  Closure to order objects in the list.
     */

    var sortBlock: ListDifferenceSortBlock { get }

    /**
     *  Applies changes to the list resulting in list of ```ListDifference``` items.
     *
     *  Call to this method should always modify ```allItems``` and ```lastDifferences```
     *  properties.
     *
     *  - parameter:
     *    - changes: List of changes to apply to current ordered list.
     */

    func apply(changes: [DataProviderChange<Model>])
}

/**
 *  Class is designed to provide an implementation of ```ListDifferenceCalculatorProtocol```.
 *  Calculator accepts initial sorted list of objects and sortition closure to calculates changes
 *  in the list on request.
 *
 *  This implementation is aimed to connect data provider with user interface providing all
 *  necessary information to animate changes in ```UITableView``` or ```UICollectionView```.
 *
 *  Use ```limit``` property to control maximum number of items in the list. But note that changing
 *  the value in runtime might implicitly clear ```lastDifferences``` list.
 */

public final class ListDifferenceCalculator<T: Identifiable>: ListDifferenceCalculatorProtocol {
    public typealias Model = T

    public private(set) var allItems: [T]
    public private(set) var lastDifferences: [ListDifference<T>] = []
    public private(set) var sortBlock: ListDifferenceSortBlock

    public var limit: Int {
        didSet {
            handleLimitChanges()
        }
    }

    /**
     *  Creates difference calculator object.
     *
     *  - parameters:
     *    - initialItems: List of items to start with. It is assumed that the list is
     *    already sorted according to sortition closure.
     *    - limit: Maximum number of objects that calculator must maintain. Pass zero to prevent
     *      any restriction. By default is zero.
     *    - sortBlock: Sortition closure that define order in the list.
     */

    public init(initialItems: [T], limit: Int = 0, sortBlock: @escaping ListDifferenceSortBlock) {
        allItems = initialItems
        self.sortBlock = sortBlock
        self.limit = limit
    }

    public func apply(changes: [DataProviderChange<T>]) {
        lastDifferences.removeAll()

        var deleteIdentifiers = Set<String>()

        var insertItems = [String: Model]()

        for change in changes {
            switch change {
            case let .insert(newItem):
                insertItems[newItem.identifier] = newItem
            case let .update(newItem):
                if let oldItemIndex = allItems
                    .firstIndex(where: { $0.identifier == newItem.identifier })
                {
                    // If updating value changes the order than replace update with delete + insert

                    if sortBlock(newItem, allItems[oldItemIndex]) == sortBlock(
                        allItems[oldItemIndex],
                        newItem
                    ) {
                        lastDifferences.append(.update(
                            index: oldItemIndex,
                            old: allItems[oldItemIndex],
                            new: newItem
                        ))
                        allItems[oldItemIndex] = newItem
                    } else {
                        deleteIdentifiers.insert(newItem.identifier)
                        insertItems[newItem.identifier] = newItem
                    }
                } else if limit > 0, allItems.count == limit {
                    // it might be the case that updating item were out of bounds previously

                    if sortBlock(newItem, allItems[allItems.count - 1]) {
                        insertItems[newItem.identifier] = newItem
                    }
                }

            case let .delete(deletedIdentifier):
                deleteIdentifiers.insert(deletedIdentifier)
            }
        }

        applyConstraints(insertItems: &insertItems, deleteIdentifiers: &deleteIdentifiers)

        if !deleteIdentifiers.isEmpty {
            delete(
                identifiers: deleteIdentifiers,
                targetList: &allItems,
                diffList: &lastDifferences
            )
        }

        if !insertItems.isEmpty {
            insert(
                items: Array(insertItems.values),
                targetList: &allItems,
                diffList: &lastDifferences
            )
        }
    }

    private func applyConstraints(
        insertItems: inout [String: Model],
        deleteIdentifiers: inout Set<String>
    ) {
        guard limit > 0 else {
            return
        }

        var targetList = allItems
        var diffList: [ListDifference<Model>] = []

        if !deleteIdentifiers.isEmpty {
            delete(
                identifiers: deleteIdentifiers,
                targetList: &targetList,
                diffList: &diffList
            )
        }

        if !insertItems.isEmpty {
            insert(
                items: Array(insertItems.values),
                targetList: &targetList,
                diffList: &diffList
            )
        }

        if targetList.count > limit {
            let implicitDeleteIdentifiers = targetList[limit ..< targetList.count]
                .reduce(into: Set()) { $0.insert($1.identifier) }
            deleteIdentifiers.formUnion(implicitDeleteIdentifiers)

            insertItems = insertItems
                .filter { !implicitDeleteIdentifiers.contains($0.value.identifier) }
        }
    }

    private func handleLimitChanges() {
        guard limit > 0, allItems.count > limit else {
            return
        }

        lastDifferences.removeAll()

        let implicitDeleteIdentifiers = allItems[limit ..< allItems.count]
            .reduce(into: Set()) { $0.insert($1.identifier) }

        delete(
            identifiers: implicitDeleteIdentifiers,
            targetList: &allItems,
            diffList: &lastDifferences
        )
    }

    private func delete(
        identifiers: Set<String>,
        targetList: inout [Model],
        diffList: inout [ListDifference<Model>]
    ) {
        // delete changes should be sorted by index desc

        for (index, oldItem) in targetList.enumerated().reversed() {
            if identifiers.contains(oldItem.identifier) {
                diffList.append(.delete(index: index, old: oldItem))
            }
        }

        targetList.removeAll { item in
            identifiers.contains(item.identifier)
        }
    }

    private func insert(
        items: [T],
        targetList: inout [Model],
        diffList: inout [ListDifference<Model>]
    ) {
        targetList.append(contentsOf: items)
        targetList.sort(by: sortBlock)

        // insert changes should be sorted by index asc

        for (index, item) in targetList.enumerated() {
            if items.contains(where: { $0.identifier == item.identifier }) {
                diffList.append(.insert(index: index, new: item))
            }
        }
    }
}
