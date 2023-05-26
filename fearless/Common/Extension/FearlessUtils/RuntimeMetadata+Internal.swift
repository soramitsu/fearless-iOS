import Foundation
import SSFUtils

extension RuntimeMetadata {
    func getStorageMetadata(for codingPath: StorageCodingPath) -> RuntimeStorageEntryMetadata? {
        getStorageMetadata(in: codingPath.moduleName, storageName: codingPath.itemName)
    }

    func createEventCodingPath(from moduleName: String, eventName: String) -> EventCodingPath? {
        guard let module = modules.first(where: { $0.name == moduleName }) else {
            return nil
        }

        return EventCodingPath(moduleName: module.name, eventName: eventName)
    }

    func createEventCodingPath(from event: Event) -> EventCodingPath? {
        createEventCodingPath(from: event.section, eventName: event.method)
    }
}
