import Foundation
import Testing
@testable import task_manager

struct MusicPracticeModelTests {
    @Test func practicePieceAndSessionCleanInputs() {
        let piece = PracticePiece(
            title: "  Prelude  ",
            composer: "  Bach  ",
            catalogOrOpus: "  BWV 846  ",
            instrument: "   ",
            notes: "  hands separate  "
        )
        let session = PracticeSession(
            durationMinutes: -20,
            pieceID: piece.id,
            focusArea: .technique,
            notes: "  scales  ",
            qualityRating: 8
        )

        #expect(piece.title == "Prelude")
        #expect(piece.composer == "Bach")
        #expect(piece.catalogOrOpus == "BWV 846")
        #expect(piece.instrument == "Piano")
        #expect(piece.notes == "hands separate")
        #expect(PracticePiece(newTitle: "  ") == nil)
        #expect(session.durationMinutes == 0)
        #expect(session.notes == "scales")
        #expect(session.qualityRating == 5)
    }

    @Test func practiceDateWindowContainsCurrentDaysAndExcludesEnd() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 12))!
        let window = PracticeDateWindow.current(days: 7, endingAt: now, calendar: calendar)!
        let firstIncludedDay = calendar.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 0))!
        let previousDay = calendar.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 23))!
        let nextDayStart = calendar.date(from: DateComponents(year: 2026, month: 5, day: 12, hour: 0))!

        #expect(window.contains(firstIncludedDay))
        #expect(window.contains(now))
        #expect(window.contains(previousDay) == false)
        #expect(window.contains(nextDayStart) == false)
        #expect(PracticeSession(date: now, durationMinutes: 15).isInDateRange(start: window.start, end: window.end))
    }

    @Test func musicPracticeSummaryCalculatesWindowsAndFocusBreakdown() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pieceAID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let pieceBID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let pieceCID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let archivedPieceID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 12))!
        let sameDay = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 10))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: now)!
        let thirtyOneDaysAgo = calendar.date(byAdding: .day, value: -31, to: now)!
        let pieceA = PracticePiece(id: pieceAID, title: "Prelude")
        let pieceB = PracticePiece(id: pieceBID, title: "Invention")
        let pieceC = PracticePiece(id: pieceCID, title: "Nocturne")
        let archivedPiece = PracticePiece(id: archivedPieceID, title: "Old Study", status: .archived)
        let sessions = [
            PracticeSession(date: now, durationMinutes: 30, pieceID: pieceAID, focusArea: .repertoire),
            PracticeSession(date: sameDay, durationMinutes: 10, focusArea: .warmup),
            PracticeSession(date: yesterday, durationMinutes: 20, pieceID: pieceAID, focusArea: .technique),
            PracticeSession(date: eightDaysAgo, durationMinutes: 40, pieceID: pieceBID, focusArea: .sightReading),
            PracticeSession(date: thirtyOneDaysAgo, durationMinutes: 60, pieceID: pieceCID, focusArea: .repertoire),
        ]

        let summary = MusicPracticeSummary(
            sessions: sessions,
            pieces: [pieceC, archivedPiece, pieceB, pieceA],
            now: now,
            calendar: calendar,
            recentSessionLimit: 3
        )

        #expect(summary.totalMinutesLast7Days == 60)
        #expect(summary.totalMinutesLast30Days == 100)
        #expect(summary.recentSessions.map(\.durationMinutes) == [30, 10, 20])
        #expect(summary.recentlyPracticedPieces.map(\.id) == [pieceAID, pieceBID, pieceCID])
        #expect(summary.piecesNotPracticedRecently.map(\.id) == [pieceCID])
        #expect(summary.focusAreaMinutesLast30Days[.repertoire] == 30)
        #expect(summary.focusAreaMinutesLast30Days[.warmup] == 10)
        #expect(summary.focusAreaMinutesLast30Days[.technique] == 20)
        #expect(summary.focusAreaMinutesLast30Days[.sightReading] == 40)
    }
}
