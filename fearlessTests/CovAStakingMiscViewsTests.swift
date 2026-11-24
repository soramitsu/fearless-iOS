import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAStakingMiscViewsTests: XCTestCase {
    func testSelectedValidatorCellBindsNameAddressAndStatus() throws {
        let cell = SelectedValidatorCell(style: .default, reuseIdentifier: "cov-a")
        let icon = try UniversalIconGenerator().generateFromAddress(CovAFixtures.address(1))
        cell.bind(viewModel: SelectedValidatorCellViewModel(
            icon: icon,
            name: "Named",
            address: CovAFixtures.address(1),
            detailsAttributedString: NSAttributedString(string: "APY 10%"),
            detailsAux: nil,
            shouldShowWarning: true,
            shouldShowError: true
        ))
        XCTAssertEqual(cell.titleLabel.text, "Named")
        XCTAssertEqual(cell.detailsLabel.attributedText?.string, "APY 10%")
        XCTAssertEqual(cell.statusStackView.arrangedSubviews.count, 2)

        cell.bind(viewModel: SelectedValidatorCellViewModel(
            icon: nil,
            name: nil,
            address: CovAFixtures.address(2),
            detailsAttributedString: nil,
            detailsAux: nil,
            shouldShowWarning: false,
            shouldShowError: false
        ))
        XCTAssertEqual(cell.titleLabel.text, CovAFixtures.address(2))
        XCTAssertEqual(cell.titleLabel.lineBreakMode, .byTruncatingMiddle)
        XCTAssertTrue(cell.statusStackView.arrangedSubviews.isEmpty)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 64)
        cell.layoutIfNeeded()
    }

    func testCustomValidatorListHeaderBindsTitles() {
        let header = CustomValidatorListHeaderView(reuseIdentifier: "cov-a")
        header.bind(title: "12 of 300", details: "Rewards")
        XCTAssertEqual(header.titleLabel.text, "12 OF 300")
        XCTAssertEqual(header.detailsLabel.text, "REWARDS")
        header.bind(viewModel: TitleWithSubtitleViewModel(title: "1 of 2", subtitle: "Own stake"))
        XCTAssertEqual(header.titleLabel.text?.lowercased(), "1 of 2")
        XCTAssertEqual(header.detailsLabel.text?.lowercased(), "own stake")
    }

    func testPendingNominatorBecomesValidatorOrBonded() throws {
        func makeMachine() -> (StakingStateMachine, CovAStakingStateRecorder) {
            let machine = StakingStateMachine()
            let recorder = CovAStakingStateRecorder()
            machine.delegate = recorder
            machine.state.process(chainAsset: CovAFixtures.chainAsset())
            machine.state.process(stashItem: CovAStakingMainFixtures.stash())
            machine.state.process(validatorPrefs: nil)
            return (machine, recorder)
        }

        let (validator, validatorRecorder) = makeMachine()
        XCTAssertEqual(validatorRecorder.last, "pendingNominator")
        try validator.state.process(ledgerInfo: CovAStakingMainFixtures.ledger())
        XCTAssertEqual(validatorRecorder.last, "pendingNominator", "a ledger without a nomination keeps waiting")
        validator.state.process(validatorPrefs: CovAStakingMainFixtures.prefs())
        XCTAssertEqual(validatorRecorder.last, "validator")

        let (pending, pendingRecorder) = makeMachine()
        pending.state.process(validatorPrefs: CovAStakingMainFixtures.prefs())
        XCTAssertEqual(pendingRecorder.last, "pendingValidator")

        let (bonded, bondedRecorder) = makeMachine()
        try bonded.state.process(ledgerInfo: CovAStakingMainFixtures.ledger())
        bonded.state.process(nomination: nil)
        XCTAssertEqual(bondedRecorder.last, "bonded")

        let (nominator, nominatorRecorder) = makeMachine()
        try nominator.state.process(nomination: CovAStakingMainFixtures.nomination())
        XCTAssertEqual(nominatorRecorder.last, "pendingNominator")
        nominator.state.process(totalReward: CovAStakingMainFixtures.totalReward())
        nominator.state.process(payee: .stash)
        try nominator.state.process(ledgerInfo: CovAStakingMainFixtures.ledger())
        XCTAssertEqual(nominatorRecorder.last, "nominator")
        XCTAssertEqual((nominator.state as? NominatorState)?.payee, .stash)
    }
}
