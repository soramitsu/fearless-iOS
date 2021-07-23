import Foundation

struct EraCountdown {
    let activeEra: EraIndex
    let eraLength: SessionIndex
    let sessionLength: SessionIndex
    let eraStartSessionIndex: SessionIndex
    let currentSessionIndex: SessionIndex
    let currentSlot: Slot
    let genesisSlot: Slot
    let blockCreationTime: Moment
    let createdAtDate: Date

    var eraCompletionTime: TimeInterval {
        let numberOfSlotsPerSession = UInt64(sessionLength)
        let currentSessionIndexInt = UInt64(currentSessionIndex)

        let sessionStartSlot = currentSessionIndexInt * numberOfSlotsPerSession + genesisSlot
        let sessionProgress = currentSlot - sessionStartSlot
        let eraProgress = (currentSessionIndexInt - UInt64(eraStartSessionIndex)) * numberOfSlotsPerSession
            + sessionProgress
        if Int64(eraLength * sessionLength) - Int64(eraProgress) < 0 {
            return 0
        }
        let eraRemained = UInt64(eraLength) * numberOfSlotsPerSession - eraProgress
        let result = eraRemained * UInt64(blockCreationTime)

        let datesTimeinterval = Date().timeIntervalSince(createdAtDate)
        let remainedTime = TimeInterval(result).seconds - datesTimeinterval
        return remainedTime
    }
}
