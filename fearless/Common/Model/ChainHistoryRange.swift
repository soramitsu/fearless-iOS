import Foundation

struct ChainHistoryRange {
    let currentEra: EraIndex
    let activeEra: EraIndex
    let historyDepth: UInt32

    var erasRange: [EraIndex] {
        Array(currentEra - historyDepth ... activeEra - 1)
    }
}
