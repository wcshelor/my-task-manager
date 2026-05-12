import Combine
import Foundation

@MainActor
final class MusicPracticeViewModel: ObservableObject {
    @Published private(set) var pieces: [PracticePiece] = []
    @Published private(set) var recentSessions: [PracticeSession] = []
    @Published private(set) var summary = MusicPracticeSummary(
        sessions: [],
        pieces: [],
        now: Date(),
        calendar: .current
    )
    @Published private(set) var errorMessage: String?

    private let musicPracticeRepository: any MusicPracticeRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false

    init(
        musicPracticeRepository: any MusicPracticeRepository,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.musicPracticeRepository = musicPracticeRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var piecesByID: [UUID: PracticePiece] {
        Dictionary(uniqueKeysWithValues: pieces.map { ($0.id, $0) })
    }

    var totalPracticeSummary: String {
        if summary.totalMinutesLast7Days > 0 {
            return "\(summary.totalMinutesLast7Days)m in the last 7 days"
        }

        if summary.totalMinutesLast30Days > 0 {
            return "\(summary.totalMinutesLast30Days)m in the last 30 days"
        }

        return "No practice logged yet"
    }

    func pieceTitle(for id: UUID?) -> String? {
        id.flatMap { piecesByID[$0]?.title }
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        load()
    }

    func load() {
        do {
            let now = nowProvider()
            pieces = try musicPracticeRepository.fetchPracticePieces(includeArchived: false)
            recentSessions = try musicPracticeRepository.fetchPracticeSessions(limit: 20)
            let window = PracticeDateWindow.current(days: 30, endingAt: now, calendar: calendar)
            let summarySessions = try window.map { window in
                try musicPracticeRepository.fetchPracticeSessions(from: window.start, to: window.end)
            } ?? recentSessions
            summary = MusicPracticeSummary(
                sessions: summarySessions,
                pieces: pieces,
                now: now,
                calendar: calendar
            )
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load Music Practice: \(error.localizedDescription)"
        }
    }

    func savePiece(_ piece: PracticePiece, replacingPieceWithID originalID: UUID? = nil) {
        do {
            try musicPracticeRepository.savePracticePiece(piece, replacingPieceWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save piece: \(error.localizedDescription)"
        }
    }

    func saveSession(_ session: PracticeSession, replacingSessionWithID originalID: UUID? = nil) {
        do {
            try musicPracticeRepository.savePracticeSession(session, replacingSessionWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save practice session: \(error.localizedDescription)"
        }
    }

    func deleteSession(withID id: UUID) {
        do {
            try musicPracticeRepository.deletePracticeSession(withID: id)
            load()
        } catch {
            errorMessage = "Unable to delete practice session: \(error.localizedDescription)"
        }
    }
}
