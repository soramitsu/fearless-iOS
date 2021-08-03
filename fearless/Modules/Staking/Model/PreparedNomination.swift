import Foundation

struct PreparedNomination<T> {
    let bonding: T
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
}
