import Foundation
import SwiftData

@Model
final class PracticeSessionRecord {
    var id: UUID = UUID()
    var date: Date = Date.distantPast
    var durationMinutes: Int = 0
    var pieceID: UUID?
    var focusAreaRawValue: String = PracticeFocusArea.repertoire.rawValue
    var notes: String?
    var qualityRating: Int?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(session: PracticeSession) {
        update(from: session)
    }

    var session: PracticeSession {
        PracticeSession(
            id: id,
            date: date,
            durationMinutes: durationMinutes,
            pieceID: pieceID,
            focusArea: PracticeFocusArea(rawValue: focusAreaRawValue) ?? .other,
            notes: notes,
            qualityRating: qualityRating,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from session: PracticeSession) {
        id = session.id
        date = session.date
        durationMinutes = session.durationMinutes
        pieceID = session.pieceID
        focusAreaRawValue = session.focusArea.rawValue
        notes = session.notes
        qualityRating = session.qualityRating
        createdAt = session.createdAt
        updatedAt = session.updatedAt
    }
}
