import Foundation

protocol RetainedDataRestoreModuleInput: AnyObject {}

struct EmergencyWalletMaterial: Codable, Equatable {
    struct Record: Codable, Equatable {
        let tag: String
        /// Base64 encodes the original bytes, including non-UTF8 and invalid material.
        let bytesBase64: String
    }

    let format = "fearless-emergency-material-v1"
    let records: [Record]
    /// A failure reading one item never hides other readable items.
    let unreadableTags: [String]
}

protocol EmergencyWalletMaterialReading {
    func read() throws -> EmergencyWalletMaterial
}

struct RetainedDataArchive: Equatable {
    let url: URL
    let date: Date
    let canRestore: Bool
}

protocol RetainedDataArchiveManaging {
    func reevaluate(completion: @escaping ([RetainedDataArchive]) -> Void)
    func requestRestore(_ archive: RetainedDataArchive, completion: @escaping (Result<Void, Error>) -> Void)
}
