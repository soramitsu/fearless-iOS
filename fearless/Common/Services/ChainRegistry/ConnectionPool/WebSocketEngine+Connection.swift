import Foundation
import FearlessUtils

extension WebSocketEngine: ConnectionAutobalancing {
    enum Holder {
        static var ranking: [String: [ConnectionRank]] = [:]
    }

    var ranking: [ConnectionRank] {
        guard let url = self.url else {
            return []
        }

        return Holder.ranking[url.absoluteString] ?? []
    }

    func set(ranking: [ConnectionRank]) {
        guard let url = self.url else {
            return
        }

        Holder.ranking[url.absoluteString] = ranking
    }
}

extension WebSocketEngine: ConnectionStateReporting {}
