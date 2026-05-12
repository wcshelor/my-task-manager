import Foundation
import SwiftData

@MainActor
final class SwiftDataMusicPracticeRepository: MusicPracticeRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchPracticePieces(includeArchived: Bool = false) throws -> [PracticePiece] {
        let pieces = try fetchAllPieceRecords()
            .map(\.piece)
            .sortedForPracticePieces()

        guard includeArchived == false else {
            return pieces
        }

        return pieces.filter { $0.isArchived == false }
    }

    func practicePiece(withID id: UUID) throws -> PracticePiece? {
        try fetchPieceRecord(withID: id)?.piece
    }

    func savePracticePiece(_ piece: PracticePiece, replacingPieceWithID originalID: UUID?) throws {
        let record =
            try fetchPieceRecord(withID: originalID ?? piece.id)
            ?? fetchPieceRecord(withID: piece.id)

        if let record {
            record.update(from: piece)
        } else {
            modelContext.insert(PracticePieceRecord(piece: piece))
        }

        try modelContext.save()
    }

    func fetchPracticeSessions(limit: Int) throws -> [PracticeSession] {
        Array(
            try fetchAllSessionRecords()
                .map(\.session)
                .sortedForPracticeHistory()
                .prefix(max(0, limit))
        )
    }

    func fetchPracticeSessions(from startDate: Date, to endDate: Date) throws -> [PracticeSession] {
        try fetchAllSessionRecords()
            .map(\.session)
            .filter { $0.isInDateRange(start: startDate, end: endDate) }
            .sortedForPracticeHistory()
    }

    func practiceSession(withID id: UUID) throws -> PracticeSession? {
        try fetchSessionRecord(withID: id)?.session
    }

    func savePracticeSession(_ session: PracticeSession, replacingSessionWithID originalID: UUID?) throws {
        let record =
            try fetchSessionRecord(withID: originalID ?? session.id)
            ?? fetchSessionRecord(withID: session.id)

        if let record {
            record.update(from: session)
        } else {
            modelContext.insert(PracticeSessionRecord(session: session))
        }

        try modelContext.save()
    }

    func deletePracticeSession(withID id: UUID) throws {
        guard let record = try fetchSessionRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchAllPieceRecords() throws -> [PracticePieceRecord] {
        try modelContext.fetch(FetchDescriptor<PracticePieceRecord>())
    }

    private func fetchPieceRecord(withID id: UUID) throws -> PracticePieceRecord? {
        try fetchAllPieceRecords().first { $0.id == id }
    }

    private func fetchAllSessionRecords() throws -> [PracticeSessionRecord] {
        try modelContext.fetch(FetchDescriptor<PracticeSessionRecord>())
    }

    private func fetchSessionRecord(withID id: UUID) throws -> PracticeSessionRecord? {
        try fetchAllSessionRecords().first { $0.id == id }
    }
}
