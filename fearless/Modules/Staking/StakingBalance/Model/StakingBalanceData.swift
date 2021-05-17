import BigInt

struct StakingBalanceData {
    let stakingLedger: StakingLedger
    let activeEra: EraIndex
    let priceData: PriceData?
}
