import Foundation
import SwiftData

@Model
final class PVTSessionRecord {
    var id: UUID = UUID()
    var startedAt: Date = Date.distantPast
    var durationSeconds: Int = 0
    var reactionTimesMillisecondsText: String = ""
    var falseStartCount: Int = 0
    var missCount: Int = 0
    var notes: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(session: PVTSession) {
        update(from: session)
    }

    var session: PVTSession {
        PVTSession(
            id: id,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            reactionTimesMilliseconds: Self.decodeReactionTimes(reactionTimesMillisecondsText),
            falseStartCount: falseStartCount,
            missCount: missCount,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from session: PVTSession) {
        id = session.id
        startedAt = session.startedAt
        durationSeconds = session.durationSeconds
        reactionTimesMillisecondsText = Self.encodeReactionTimes(session.reactionTimesMilliseconds)
        falseStartCount = session.falseStartCount
        missCount = session.missCount
        notes = session.notes
        createdAt = session.createdAt
        updatedAt = session.updatedAt
    }

    private static func encodeReactionTimes(_ reactionTimes: [Int]) -> String {
        reactionTimes.map(String.init).joined(separator: ",")
    }

    private static func decodeReactionTimes(_ text: String) -> [Int] {
        PVTSession.cleanedReactionTimes(
            text
                .split(separator: ",")
                .compactMap { Int($0) }
        )
    }
}
