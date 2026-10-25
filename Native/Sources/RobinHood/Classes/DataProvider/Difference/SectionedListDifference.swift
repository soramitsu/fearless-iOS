/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Enum is designed to define changes in sectioned list of objects.
 */

public enum SectionedListDifference<Section, Item> {
    /// New section inserted at given index.
    /// An index and new section object are passed as associated values.
    case insert(index: Int, newSection: Section)

    /// Existing section is updated at given index.
    /// An index, changes and existing section are passed as associated values.
    case update(index: Int, itemChange: ListDifference<Item>, section: Section)

    /// Existing section was deleted at given index.
    /// An index and a section is passed as associated values.
    case delete(index: Int, oldSection: Section)
}
