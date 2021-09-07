import Foundation

struct ChainHistoryRange {
    let currentEra: EraIndex
    let activeEra: EraIndex
    let historyDepth: UInt32

    var eraRange: EraRange {
        let start = max(currentEra - historyDepth, 0)
        let end = max(activeEra - 1, 0)
        return EraRange(start, end)
    }

    var eraList: [EraIndex] {
        let range = eraRange
        return Array(range.start ... range.end)
    }
}
