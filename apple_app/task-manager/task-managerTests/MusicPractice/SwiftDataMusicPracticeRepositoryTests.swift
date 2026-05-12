import Foundation
import Testing
@testable import task_manager

struct SwiftDataMusicPracticeRepositoryTests {
    @Test @MainActor func musicPracticeRepositoryRoundTripsPieceAndSession() throws {
        let repository = try makeRepository()
        let piece = PracticePiece(title: "Prelude", composer: "Bach", catalogOrOpus: "BWV 846")
        let session = PracticeSession(
            date: Date(timeIntervalSince1970: 1_000),
            durationMinutes: 25,
            pieceID: piece.id,
            focusArea: .repertoire,
            notes: "First page",
            qualityRating: 4
        )

        try repository.savePracticePiece(piece, replacingPieceWithID: nil)
        try repository.savePracticeSession(session, replacingSessionWithID: nil)

        #expect(try repository.practicePiece(withID: piece.id) == piece)
        #expect(try repository.practiceSession(withID: session.id) == session)
        #expect(try repository.fetchPracticePieces(includeArchived: false) == [piece])
        #expect(try repository.fetchPracticeSessions(limit: 10) == [session])
        #expect(try repository.fetchPracticeSessions(limit: 10).first?.pieceID == piece.id)
    }

    @Test @MainActor func musicPracticeRepositoryFiltersArchivedPiecesAndDateRanges() throws {
        let repository = try makeRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let activePiece = PracticePiece(title: "Prelude")
        let archivedPiece = PracticePiece(title: "Old Study", status: .archived)
        let firstDay = calendar.date(from: DateComponents(year: 2026, month: 5, day: 9, hour: 10))!
        let secondDay = calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 10))!
        let thirdDay = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 10))!
        let oldSession = PracticeSession(date: firstDay, durationMinutes: 15)
        let includedSession = PracticeSession(date: secondDay, durationMinutes: 20, pieceID: activePiece.id)
        let endExcludedSession = PracticeSession(date: thirdDay, durationMinutes: 30)
        let start = calendar.startOfDay(for: secondDay)
        let end = calendar.startOfDay(for: thirdDay)

        try repository.savePracticePiece(archivedPiece, replacingPieceWithID: nil)
        try repository.savePracticePiece(activePiece, replacingPieceWithID: nil)
        try repository.savePracticeSession(oldSession, replacingSessionWithID: nil)
        try repository.savePracticeSession(endExcludedSession, replacingSessionWithID: nil)
        try repository.savePracticeSession(includedSession, replacingSessionWithID: nil)

        #expect(try repository.fetchPracticePieces(includeArchived: false) == [activePiece])
        #expect(try repository.fetchPracticePieces(includeArchived: true).map(\.id) == [archivedPiece.id, activePiece.id])
        #expect(try repository.fetchPracticeSessions(from: start, to: end) == [includedSession])
        #expect(try repository.fetchPracticeSessions(limit: 2).map(\.id) == [endExcludedSession.id, includedSession.id])
    }

    @Test @MainActor func musicPracticeRepositoryUpdatesAndDeletesSessions() throws {
        let repository = try makeRepository()
        let original = PracticeSession(durationMinutes: 10, focusArea: .warmup)
        let updated = PracticeSession(
            id: original.id,
            date: original.date,
            durationMinutes: 35,
            focusArea: .technique,
            createdAt: original.createdAt
        )

        try repository.savePracticeSession(original, replacingSessionWithID: nil)
        try repository.savePracticeSession(updated, replacingSessionWithID: original.id)
        #expect(try repository.practiceSession(withID: original.id)?.durationMinutes == 35)
        #expect(try repository.practiceSession(withID: original.id)?.focusArea == .technique)

        try repository.deletePracticeSession(withID: original.id)
        #expect(try repository.fetchPracticeSessions(limit: 10).isEmpty)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataMusicPracticeRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataMusicPracticeRepository(modelContainer: container)
    }
}
