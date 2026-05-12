import Foundation
import Testing
@testable import task_manager

@MainActor
struct MusicPracticeViewModelTests {
    @Test func musicPracticeViewModelLoadsSummaryState() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 12))!
        let piece = PracticePiece(title: "Prelude")
        let session = PracticeSession(
            date: now,
            durationMinutes: 30,
            pieceID: piece.id,
            focusArea: .repertoire
        )
        let repository = FakeMusicPracticeRepository(
            pieces: [piece],
            sessions: [session]
        )
        let viewModel = MusicPracticeViewModel(
            musicPracticeRepository: repository,
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.pieces == [piece])
        #expect(viewModel.recentSessions == [session])
        #expect(viewModel.summary.totalMinutesLast7Days == 30)
        #expect(viewModel.pieceTitle(for: piece.id) == "Prelude")
        #expect(viewModel.totalPracticeSummary == "30m in the last 7 days")
    }

    @Test func musicPracticeViewModelSavesAndRefreshesRecords() {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = FakeMusicPracticeRepository()
        let viewModel = MusicPracticeViewModel(
            musicPracticeRepository: repository,
            nowProvider: { now }
        )
        let piece = PracticePiece(title: "Etude")
        let session = PracticeSession(
            date: now,
            durationMinutes: 20,
            pieceID: piece.id,
            focusArea: .technique
        )

        viewModel.loadIfNeeded()
        viewModel.savePiece(piece)
        viewModel.saveSession(session)

        #expect(viewModel.pieces == [piece])
        #expect(viewModel.recentSessions == [session])
        #expect(viewModel.summary.focusAreaMinutesLast30Days[.technique] == 20)
    }
}

private enum FakeMusicPracticeRepositoryError: Error {
    case requestedFailure
}

@MainActor
private final class FakeMusicPracticeRepository: MusicPracticeRepository {
    var pieces: [PracticePiece]
    var sessions: [PracticeSession]
    var shouldThrow: Bool

    init(
        pieces: [PracticePiece] = [],
        sessions: [PracticeSession] = [],
        shouldThrow: Bool = false
    ) {
        self.pieces = pieces
        self.sessions = sessions
        self.shouldThrow = shouldThrow
    }

    func fetchPracticePieces(includeArchived: Bool) throws -> [PracticePiece] {
        try failIfNeeded()
        let sortedPieces = pieces.sortedForPracticePieces()
        guard includeArchived == false else {
            return sortedPieces
        }

        return sortedPieces.filter { $0.isArchived == false }
    }

    func practicePiece(withID id: UUID) throws -> PracticePiece? {
        try failIfNeeded()
        return pieces.first { $0.id == id }
    }

    func savePracticePiece(_ piece: PracticePiece, replacingPieceWithID originalID: UUID?) throws {
        try failIfNeeded()
        let targetID = originalID ?? piece.id
        if let index = pieces.firstIndex(where: { $0.id == targetID || $0.id == piece.id }) {
            pieces[index] = piece
        } else {
            pieces.append(piece)
        }
    }

    func fetchPracticeSessions(limit: Int) throws -> [PracticeSession] {
        try failIfNeeded()
        return Array(sessions.sortedForPracticeHistory().prefix(max(0, limit)))
    }

    func fetchPracticeSessions(from startDate: Date, to endDate: Date) throws -> [PracticeSession] {
        try failIfNeeded()
        return sessions
            .filter { $0.isInDateRange(start: startDate, end: endDate) }
            .sortedForPracticeHistory()
    }

    func practiceSession(withID id: UUID) throws -> PracticeSession? {
        try failIfNeeded()
        return sessions.first { $0.id == id }
    }

    func savePracticeSession(_ session: PracticeSession, replacingSessionWithID originalID: UUID?) throws {
        try failIfNeeded()
        let targetID = originalID ?? session.id
        if let index = sessions.firstIndex(where: { $0.id == targetID || $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func deletePracticeSession(withID id: UUID) throws {
        try failIfNeeded()
        sessions.removeAll { $0.id == id }
    }

    private func failIfNeeded() throws {
        if shouldThrow {
            throw FakeMusicPracticeRepositoryError.requestedFailure
        }
    }
}
