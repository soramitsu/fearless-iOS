// Swift 6: restate inherited @unchecked Sendable for Operation subclasses and decoders
// This keeps strict concurrency happy without invasive changes.

#if swift(>=6.0)
    import Foundation

    // BaseOperation subclasses
    extension UnkeyedEncodingOperation: @unchecked Sendable {}
    extension MapKeyEncodingOperation: @unchecked Sendable {}
    extension DoubleMapKeyEncodingOperation: @unchecked Sendable {}
    extension NMapKeyEncodingOperation: @unchecked Sendable {}
    extension StorageDecodingOperation: @unchecked Sendable {}
    extension StorageFallbackDecodingOperation: @unchecked Sendable {}
    extension StorageDecodingListOperation: @unchecked Sendable {}
    extension StorageFallbackDecodingListOperation: @unchecked Sendable {}
    extension StorageConstantOperation: @unchecked Sendable {}
    extension PrimitiveConstantOperation: @unchecked Sendable {}
    extension AwaitOperation: @unchecked Sendable {}
    extension ManualOperation: @unchecked Sendable {}
    extension LongrunOperation: @unchecked Sendable {}

    // JSONDecoder subclasses
    extension NomisJSONDecoder: @unchecked Sendable {}
    extension GithubJSONDecoder: @unchecked Sendable {}
#endif
