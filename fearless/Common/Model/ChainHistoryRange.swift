import Foundation

struct ChainHistoryRange {
    let currentEra: EraIndex
    let activeEra: EraIndex
    let historyDepth: UInt32

    var eraRange: EraRange {
        let start: EraIndex = {
            if currentEra >= historyDepth {
                return currentEra - historyDepth
            } else {
                return 0
            }
        }()

        let end: EraIndex = {
            if activeEra >= 1 {
                return activeEra - 1
            } else {
                return 0
            }
        }()

        return EraRange(start, end)
    }

    var eraList: [EraIndex] {
        let range = eraRange
        return Array(range.start ... range.end)
    }
}
