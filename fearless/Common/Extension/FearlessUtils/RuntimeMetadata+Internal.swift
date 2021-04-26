import Foundation
import FearlessUtils

extension RuntimeMetadata {
    func getStorageMetadata(for codingPath: StorageCodingPath) -> StorageEntryMetadata? {
        getStorageMetadata(in: codingPath.moduleName, storageName: codingPath.itemName)
    }

    func createEventCodingPath(from moduleIndex: UInt8, eventIndex: UInt32) -> EventCodingPath? {
        guard let module = modules.first(where: { $0.index == moduleIndex }) else {
            return nil
        }

        guard let events = module.events, eventIndex < events.count else {
            return nil
        }

        return EventCodingPath(moduleName: module.name, eventName: events[Int(eventIndex)].name)
    }

    func createEventCodingPath(from event: Event) -> EventCodingPath? {
        createEventCodingPath(from: event.moduleIndex, eventIndex: event.eventIndex)
    }
}
