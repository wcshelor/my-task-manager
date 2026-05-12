import Foundation

@MainActor
protocol MusicPracticeRepository {
    func fetchPracticePieces(includeArchived: Bool) throws -> [PracticePiece]
    func practicePiece(withID id: UUID) throws -> PracticePiece?
    func savePracticePiece(_ piece: PracticePiece, replacingPieceWithID originalID: UUID?) throws

    func fetchPracticeSessions(limit: Int) throws -> [PracticeSession]
    func fetchPracticeSessions(from startDate: Date, to endDate: Date) throws -> [PracticeSession]
    func practiceSession(withID id: UUID) throws -> PracticeSession?
    func savePracticeSession(_ session: PracticeSession, replacingSessionWithID originalID: UUID?) throws
    func deletePracticeSession(withID id: UUID) throws
}
