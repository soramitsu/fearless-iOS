struct EraCountdownSteps {
    let eraLength: SessionIndex
    let sessionLength: SessionIndex
    let eraStartSessionIndex: SessionIndex
    let currentSessionIndex: SessionIndex
    let currentSlot: Slot
    let genesisSlot: Slot
    let blockCreationTime: Moment
}
