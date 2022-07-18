import BigInt

struct StakingBalanceData {
    let stakingLedger: StakingLedger
    let activeEra: EraIndex
    let eraCountdown: EraCountdown?
}
