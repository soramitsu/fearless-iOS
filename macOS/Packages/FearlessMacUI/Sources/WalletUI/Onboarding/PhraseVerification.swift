import Foundation
import Observation

/// One question of the backup check: "which word is number N?".
struct VerifyChallenge: Identifiable, Equatable {
    /// Zero-based position in the phrase.
    let position: Int
    let options: [String]
    var selection: String?

    var id: Int { position }
}

/// Checks that the user wrote the phrase down: for a few random positions
/// they pick the right word among decoys.
@MainActor
@Observable
final class PhraseVerification {
    @ObservationIgnored private let words: [String]
    private(set) var challenges: [VerifyChallenge]

    /// - Parameters:
    ///   - words: the recovery phrase.
    ///   - wordList: where decoys come from (the BIP-39 list).
    ///   - count: how many positions to ask; three for 12 words, four for longer phrases.
    init<Generator: RandomNumberGenerator>(words: [String], wordList: [String], count: Int? = nil, using generator: inout Generator) {
        self.words = words
        let wanted = min(words.count, count ?? (words.count > 12 ? 4 : 3))
        let positions = Array(words.indices).shuffled(using: &generator).prefix(wanted).sorted()
        challenges = positions.map { position in
            let answer = words[position]
            var decoys: [String] = []
            var pool = (words + wordList.shuffled(using: &generator).prefix(40)).filter { $0 != answer }
            pool.shuffle(using: &generator)
            for candidate in pool where !decoys.contains(candidate) {
                decoys.append(candidate)
                if decoys.count == 5 { break }
            }
            return VerifyChallenge(position: position, options: (decoys + [answer]).shuffled(using: &generator), selection: nil)
        }
    }

    convenience init(words: [String], wordList: [String], count: Int? = nil) {
        var generator = SystemRandomNumberGenerator()
        self.init(words: words, wordList: wordList, count: count, using: &generator)
    }

    func select(_ word: String, for position: Int) {
        guard let index = challenges.firstIndex(where: { $0.position == position }) else { return }
        challenges[index].selection = word
    }

    /// Nil until answered.
    func isCorrect(_ challenge: VerifyChallenge) -> Bool? {
        guard let selection = challenge.selection, words.indices.contains(challenge.position) else { return nil }
        return selection == words[challenge.position]
    }

    var answeredCount: Int {
        challenges.filter { $0.selection != nil }.count
    }

    var hasMistake: Bool {
        challenges.contains { isCorrect($0) == false }
    }

    /// True when every position was answered correctly.
    var isComplete: Bool {
        !challenges.isEmpty && challenges.allSatisfy { isCorrect($0) == true }
    }
}
