import CoreData
import Darwin
import Foundation

// Prints, as one JSON line per <source.mom> <destination.mom> pair, what Core
// Data's inferred mapping from source to destination would lose or fail on:
//
// - droppedEntities: source entities the destination does not have;
// - droppedProperties: `Entity.property` attributes and relationships of shared
//   entities that the destination does not have;
// - unsatisfiedRequiredAttributes: destination attributes that the inferred
//   mapping leaves without a value although they are mandatory and have no
//   default. Migrating a store with rows of that entity fails with Cocoa error
//   134110 unless a custom mapping supplies a constant.
//
// Names are compared exactly, as the migrator's drop guard does, so a renamed
// property counts as dropped. That can only make the check stricter.

let pairs = Array(CommandLine.arguments.dropFirst())
guard !pairs.isEmpty, pairs.count.isMultiple(of: 2) else {
    fputs("usage: historical-model-inferred-drops.swift <source.mom> <destination.mom> [...]\n", stderr)
    exit(EX_USAGE)
}

func loadModel(_ path: String) -> NSManagedObjectModel {
    guard let model = NSManagedObjectModel(contentsOf: URL(fileURLWithPath: path)) else {
        fputs("unable to load Core Data model: \(path)\n", stderr)
        exit(EX_DATAERR)
    }
    return model
}

func emit(_ record: [String: Any]) {
    guard
        let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
        let line = String(data: data, encoding: .utf8)
    else {
        fputs("unable to encode inferred-mapping report\n", stderr)
        exit(EX_SOFTWARE)
    }
    print(line)
}

func report(sourcePath: String, destinationPath: String) -> [String: Any] {
    let source = loadModel(sourcePath)
    let destination = loadModel(destinationPath)

    let mapping: NSMappingModel
    do {
        mapping = try NSMappingModel.inferredMappingModel(forSourceModel: source, destinationModel: destination)
    } catch {
        return [
            "source": sourcePath,
            "destination": destinationPath,
            "inferred": false,
            "error": "\(error)"
        ]
    }

    let droppedEntities = Set(source.entitiesByName.keys)
        .subtracting(destination.entitiesByName.keys)
        .sorted()

    var droppedProperties: [String] = []
    for (name, sourceEntity) in source.entitiesByName {
        guard let destinationEntity = destination.entitiesByName[name] else { continue }
        for property in sourceEntity.propertiesByName.keys where destinationEntity.propertiesByName[property] == nil {
            droppedProperties.append("\(name).\(property)")
        }
    }

    var unsatisfiedRequiredAttributes: [String] = []
    for entityMapping in mapping.entityMappings {
        guard
            entityMapping.sourceEntityName != nil,
            let destinationName = entityMapping.destinationEntityName,
            let destinationEntity = destination.entitiesByName[destinationName]
        else { continue }

        for propertyMapping in entityMapping.attributeMappings ?? [] where propertyMapping.valueExpression == nil {
            guard
                let name = propertyMapping.name,
                let attribute = destinationEntity.attributesByName[name],
                !attribute.isOptional,
                !attribute.isTransient,
                attribute.defaultValue == nil
            else { continue }
            unsatisfiedRequiredAttributes.append("\(destinationName).\(name)")
        }
    }

    return [
        "source": sourcePath,
        "destination": destinationPath,
        "inferred": true,
        "droppedEntities": droppedEntities,
        "droppedProperties": droppedProperties.sorted(),
        "unsatisfiedRequiredAttributes": unsatisfiedRequiredAttributes.sorted()
    ]
}

for index in stride(from: 0, to: pairs.count, by: 2) {
    emit(report(sourcePath: pairs[index], destinationPath: pairs[index + 1]))
}
