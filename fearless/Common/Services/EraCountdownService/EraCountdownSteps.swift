struct EraCountdownSteps {
    let numberOfSessionsPerEra: SessionIndex
    let numberOfSlotsPerSession: SessionIndex
    let eraStartSessionIndex: SessionIndex
    let currentSessionIndex: SessionIndex
    let currentSlot: Slot
    let genesisSlot: Slot
    let blockCreationTime: Moment
}
