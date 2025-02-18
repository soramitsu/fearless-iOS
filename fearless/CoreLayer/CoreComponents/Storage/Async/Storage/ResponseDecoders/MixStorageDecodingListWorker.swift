//
//  MixStorageDecodingListWorker.swift
//
//
//  Created by Soramitsu on 13.04.2024.
//

import Foundation
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

final class MixStorageDecodingListWorker: StorageDecodable, StorageModifierHandling {
    private let requests: [any MixStorageRequest]
    private let updates: [[StorageUpdate]]
    private let codingFactory: RuntimeCoderFactoryProtocol

    init(
        requests: [any MixStorageRequest],
        updates: [[StorageUpdate]],
        codingFactory: RuntimeCoderFactoryProtocol
    ) {
        self.requests = requests
        self.updates = updates
        self.codingFactory = codingFactory
    }

    func performDecoding() throws -> [MixStorageResponse] {
        let dataList = updates
            .flatMap { $0 }
            .flatMap { StorageUpdateData(update: $0).changes }
            .map { $0.value }

        let responses: [MixStorageResponse] = try zip(requests, dataList).map { request, data in
            var json: JSON?
            if let data = data {
                json = try decode(
                    data: data,
                    path: request.storagePath,
                    codingFactory: codingFactory
                )
            } else {
                json = try handleModifier(
                    at: request.storagePath,
                    codingFactory: codingFactory
                )
            }
            let response = MixStorageResponse(request: request, json: json)
            return response
        }

        return responses
    }
}
