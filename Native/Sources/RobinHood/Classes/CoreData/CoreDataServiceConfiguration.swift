/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Structure is designed to provide setup values for Core Data service.
 *  See ```CoreDataServiceProtocol``` for more details.
 */

public struct CoreDataServiceConfiguration: CoreDataServiceConfigurationProtocol {
    /// URL to Core Data entity model.
    public var modelURL: URL

    /// Type of the Core Data store.
    public var storageType: CoreDataServiceStorageType

    /**
     *  Creates Core Data service configuration.
     *
     *  - parameters:
     *    - modelURL: URL to Core Data entity model.
     *    - storageType: Type of the Core Data store.
     */

    public init(modelURL: URL, storageType: CoreDataServiceStorageType) {
        self.modelURL = modelURL
        self.storageType = storageType
    }
}
