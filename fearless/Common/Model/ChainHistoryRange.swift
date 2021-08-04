import Foundation

struct ChainHistoryRange {
    let currentEra: EraIndex
    let activeEra: EraIndex
    let historyDepth: UInt32

    var erasRange: [EraIndex] {
        let start = max(currentEra - historyDepth, 0)
        let end = max(activeEra - 1, 0)
        return Array(start ... end)
    }
}
