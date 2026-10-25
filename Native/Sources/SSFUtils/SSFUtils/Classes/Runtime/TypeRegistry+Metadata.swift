import Foundation

public extension TypeRegistry {
    static func createFromRuntimeMetadata(
        _ runtimeMetadata: RuntimeMetadata,
        additionalTypes _: Set<String> = [],
        usedRuntimePaths: [String: [String]]
    ) throws -> TypeRegistry {
        let schemaResolver = runtimeMetadata.schemaResolver
        var jsonDic: [String: JSON] = [:]
        var runtimeModules = runtimeMetadata.modules

        for (moduleName, callNames) in usedRuntimePaths {
            guard let runtimeModuleIndex = runtimeModules.firstIndex(where: {
                $0.name == moduleName
            }) else {
                continue
            }

            if let storage = runtimeModules[runtimeModuleIndex].storage {
                var storageEntrys = storage.entries

                for callName in callNames {
                    guard let storageEntryIndex = storageEntrys.firstIndex(where: {
                        $0.name == callName
                    }) else {
                        continue
                    }

                    switch storageEntrys[storageEntryIndex].type {
                    case let .plain(plain):
                        let plainType = try plain.value(using: schemaResolver)
                        jsonDic[plainType] = .stringValue(plainType)
                    case let .map(map):
                        jsonDic[map.key] = .stringValue(map.key)
                        jsonDic[map.value] = .stringValue(map.value)
                    case let .doubleMap(map):
                        jsonDic[map.key1] = .stringValue(map.key1)
                        jsonDic[map.key2] = .stringValue(map.key2)
                        jsonDic[map.value] = .stringValue(map.value)
                    case let .nMap(nMap):
                        try nMap.keys(using: schemaResolver).forEach {
                            jsonDic[$0] = .stringValue($0)
                        }
                        let nMapValue = try nMap.value(using: schemaResolver)
                        jsonDic[nMapValue] = .stringValue(nMapValue)
                    }

                    storageEntrys.remove(at: storageEntryIndex)
                }
            }

            if let calls = try runtimeModules[runtimeModuleIndex].calls(using: schemaResolver) {
                for call in calls {
                    for argument in call.arguments {
                        jsonDic[argument.type] = .stringValue(argument.type)
                    }
                }
            }

            if let events = try runtimeModules[runtimeModuleIndex].events(using: schemaResolver) {
                for event in events {
                    for argument in event.arguments {
                        jsonDic[argument] = .stringValue(argument)
                    }
                }
            }

            for constant in runtimeModules[runtimeModuleIndex].constants {
                let type = try constant.type(using: schemaResolver)
                jsonDic[type] = .stringValue(type)
            }

            runtimeModules.remove(at: runtimeModuleIndex)
        }

        let json = JSON.dictionaryValue(["types": .dictionaryValue(jsonDic)])

        return try TypeRegistry.createFromTypesDefinition(
            json: json,
            additionalNodes: [],
            schemaResolver: schemaResolver
        )
    }
}
