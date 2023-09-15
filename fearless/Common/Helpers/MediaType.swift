import Foundation
import Swime

class MediaTypeCache {
    static let shared = MediaTypeCache()
    var cache: [URL: MediaType] = [:]

    private init() {}

    func save(mediaType: MediaType?, for url: URL) {
        cache[url] = mediaType
    }
}

enum MediaType: CaseIterable {
    case image
    case video
    case gif

    static func mediaType(from url: URL) async -> MediaType? {
        if MediaTypeCache.shared.cache.contains(where: { $0.key == url }) {
            return MediaTypeCache.shared.cache[url]
        }

        if let mediaType = MediaType.allCases.first(where: { $0.pathExtensions.contains(url.pathExtension) }) {
            MediaTypeCache.shared.save(mediaType: mediaType, for: url)
            return mediaType
        } else {
            return await withCheckedContinuation { continuation in
                DispatchQueue.global().async {
                    if let mediaData = try? Data(contentsOf: url) {
                        if let mimeType = Swime.mimeType(data: mediaData)?.type {
                            switch mimeType {
                            case .jpg, .png, .tif, .heic, .bmp:
                                MediaTypeCache.shared.save(mediaType: .image, for: url)
                                return continuation.resume(with: .success(MediaType.image))
                            case .mp4, .mpg, .mov, .mkv:
                                MediaTypeCache.shared.save(mediaType: .video, for: url)
                                return continuation.resume(with: .success(MediaType.video))
                            case .gif:
                                MediaTypeCache.shared.save(mediaType: .gif, for: url)
                                return continuation.resume(with: .success(MediaType.gif))
                            default:
                                MediaTypeCache.shared.save(mediaType: nil, for: url)
                                return continuation.resume(with: .success(nil))
                            }
                        } else {
                            return continuation.resume(with: .success(nil))
                        }
                    } else {
                        return continuation.resume(with: .success(nil))
                    }
                }
            }
        }
    }

    var pathExtensions: [String] {
        switch self {
        case .image:
            return ["jpg", "jpeg", "png", "heic", "tiff", "bmp"]
        case .video:
            return ["mp4", "mpeg", "mov", "mkv"]
        case .gif:
            return ["gif"]
        }
    }
}
