import Foundation

struct EraCountdown {
    let activeEra: EraIndex
    let currentEra: EraIndex
    let eraLength: SessionIndex
    let sessionLength: SessionIndex
    let activeEraStartSessionIndex: SessionIndex
    let currentSessionIndex: SessionIndex
    let currentSlot: Slot
    let genesisSlot: Slot
    let blockCreationTime: Moment
    let createdAtDate: Date

    func timeIntervalTillStart(targetEra: EraIndex) -> TimeInterval {
        guard targetEra > activeEra else { return 0 }

        let numberOfSlotsPerSession = UInt64(sessionLength)
        let currentSessionIndexInt = UInt64(currentSessionIndex)
        let eraLengthInSlots = UInt64(sessionLength * eraLength)

        let sessionStartSlot = currentSessionIndexInt * numberOfSlotsPerSession + genesisSlot
        let sessionProgress = currentSlot - sessionStartSlot
        let eraProgress = (currentSessionIndexInt - UInt64(activeEraStartSessionIndex)) *
            numberOfSlotsPerSession + sessionProgress
        if Int64(eraLengthInSlots) - Int64(eraProgress) < 0 {
            return 0
        }
        let eraRemained = eraLengthInSlots - eraProgress
        let result = eraRemained * UInt64(blockCreationTime)

        let datesTimeinterval = Date().timeIntervalSince(createdAtDate)
        let activeEraRemainedTime = TimeInterval(result).seconds - datesTimeinterval

        let distanceBetweenEras = targetEra - (activeEra + 1)
        let targetEraDuration = distanceBetweenEras * eraLength * sessionLength * blockCreationTime
        return max(0.0, TimeInterval(targetEraDuration).seconds + activeEraRemainedTime)
    }

    func timeIntervalTillNextActiveEraStart() -> TimeInterval {
        timeIntervalTillStart(targetEra: activeEra + 1)
    }

    func timeIntervalTillSet(targetEra: EraIndex) -> TimeInterval {
        let sessionDuration = TimeInterval(sessionLength * blockCreationTime).seconds
        let tillEraStart = timeIntervalTillStart(targetEra: targetEra)

        return max(tillEraStart - sessionDuration, 0.0)
    }

    func timeIntervalTillNextCurrentEraSet() -> TimeInterval {
        timeIntervalTillSet(targetEra: currentEra + 1)
    }
}
