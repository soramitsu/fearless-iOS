import BigInt

struct StakingBalanceData {
    let stakingLedger: DyStakingLedger
    let activeEra: EraIndex
    let priceData: PriceData?
}
