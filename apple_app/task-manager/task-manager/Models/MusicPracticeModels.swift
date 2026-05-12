import Foundation

nonisolated enum PracticePieceStatus: String, CaseIterable, Codable, Hashable, Sendable {
    case learning
    case maintaining
    case polishing
    case archived

    var displayName: String {
        switch self {
        case .learning:
            return "Learning"
        case .maintaining:
            return "Maintaining"
        case .polishing:
            return "Polishing"
        case .archived:
            return "Archived"
        }
    }
}

nonisolated enum PracticeFocusArea: String, CaseIterable, Codable, Hashable, Sendable {
    case repertoire
    case technique
    case sightReading
    case improvisation
    case theory
    case earTraining
    case warmup
    case other

    var displayName: String {
        switch self {
        case .repertoire:
            return "Repertoire"
        case .technique:
            return "Technique"
        case .sightReading:
            return "Sight Reading"
        case .improvisation:
            return "Improvisation"
        case .theory:
            return "Theory"
        case .earTraining:
            return "Ear Training"
        case .warmup:
            return "Warmup"
        case .other:
            return "Other"
        }
    }
}

nonisolated struct PracticePiece: Identifiable, Equatable, Sendable {
    static let defaultInstrument = "Piano"

    let id: UUID
    var title: String
    var composer: String?
    var catalogOrOpus: String?
    var instrument: String
    var status: PracticePieceStatus
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        composer: String? = nil,
        catalogOrOpus: String? = nil,
        instrument: String = PracticePiece.defaultInstrument,
        status: PracticePieceStatus = .learning,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = Self.cleanedTitle(from: title) ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.composer = MyTask.cleanedOptionalText(from: composer)
        self.catalogOrOpus = MyTask.cleanedOptionalText(from: catalogOrOpus)
        self.instrument = Self.cleanedInstrument(from: instrument)
        self.status = status
        self.notes = MyTask.cleanedOptionalText(from: notes)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init?(
        newTitle: String,
        composer: String? = nil,
        catalogOrOpus: String? = nil,
        instrument: String = PracticePiece.defaultInstrument,
        status: PracticePieceStatus = .learning,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        guard let cleanedTitle = Self.cleanedTitle(from: newTitle) else {
            return nil
        }

        self.init(
            title: cleanedTitle,
            composer: composer,
            catalogOrOpus: catalogOrOpus,
            instrument: instrument,
            status: status,
            notes: notes,
            createdAt: createdAt
        )
    }

    var isArchived: Bool {
        status == .archived
    }

    var displaySubtitle: String {
        [composer, catalogOrOpus, instrument]
            .compactMap { $0 }
            .joined(separator: " - ")
    }

    static func cleanedTitle(from rawTitle: String) -> String? {
        MyTask.cleanedTitle(from: rawTitle)
    }

    static func cleanedInstrument(from rawInstrument: String) -> String {
        MyTask.cleanedOptionalText(from: rawInstrument) ?? Self.defaultInstrument
    }
}

nonisolated struct PracticeSession: Identifiable, Equatable, Sendable {
    let id: UUID
    var date: Date
    var durationMinutes: Int
    var pieceID: UUID?
    var focusArea: PracticeFocusArea
    var notes: String?
    var qualityRating: Int?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date = .now,
        durationMinutes: Int,
        pieceID: UUID? = nil,
        focusArea: PracticeFocusArea = .repertoire,
        notes: String? = nil,
        qualityRating: Int? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.durationMinutes = Self.cleanedDuration(durationMinutes)
        self.pieceID = pieceID
        self.focusArea = focusArea
        self.notes = MyTask.cleanedOptionalText(from: notes)
        self.qualityRating = Self.cleanedRating(qualityRating)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    func isInDateRange(start: Date, end: Date) -> Bool {
        date >= start && date < end
    }

    static func cleanedDuration(_ durationMinutes: Int) -> Int {
        max(0, durationMinutes)
    }

    static func cleanedRating(_ rating: Int?) -> Int? {
        rating.map { min(5, max(1, $0)) }
    }
}

nonisolated struct PracticeDateWindow: Equatable, Sendable {
    let start: Date
    let end: Date

    init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    static func current(days: Int, endingAt endDate: Date, calendar: Calendar) -> PracticeDateWindow? {
        guard days > 0,
              let windowEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: endDate)
              ),
              let windowStart = calendar.date(byAdding: .day, value: -days, to: windowEnd)
        else {
            return nil
        }

        return PracticeDateWindow(start: windowStart, end: windowEnd)
    }
}

nonisolated struct MusicPracticeSummary: Equatable, Sendable {
    let totalMinutesLast7Days: Int
    let totalMinutesLast30Days: Int
    let recentSessions: [PracticeSession]
    let recentlyPracticedPieces: [PracticePiece]
    let piecesNotPracticedRecently: [PracticePiece]
    let focusAreaMinutesLast30Days: [PracticeFocusArea: Int]

    init(
        sessions: [PracticeSession],
        pieces: [PracticePiece],
        now: Date,
        calendar: Calendar,
        recentSessionLimit: Int = 5
    ) {
        let sortedSessions = sessions.sortedForPracticeHistory()
        let activePieces = pieces.filter { $0.isArchived == false }.sortedForPracticePieces()
        let window7 = PracticeDateWindow.current(days: 7, endingAt: now, calendar: calendar)
        let window30 = PracticeDateWindow.current(days: 30, endingAt: now, calendar: calendar)
        let sessionsLast7 = sortedSessions.filter { session in
            window7?.contains(session.date) == true
        }
        let sessionsLast30 = sortedSessions.filter { session in
            window30?.contains(session.date) == true
        }

        totalMinutesLast7Days = sessionsLast7.map(\.durationMinutes).reduce(0, +)
        totalMinutesLast30Days = sessionsLast30.map(\.durationMinutes).reduce(0, +)
        recentSessions = Array(sortedSessions.prefix(max(0, recentSessionLimit)))
        focusAreaMinutesLast30Days = Dictionary(grouping: sessionsLast30, by: \.focusArea)
            .mapValues { sessions in
                sessions.map(\.durationMinutes).reduce(0, +)
            }

        let activePieceLookup = Dictionary(uniqueKeysWithValues: activePieces.map { ($0.id, $0) })
        var seenPieceIDs: Set<UUID> = []
        recentlyPracticedPieces = sortedSessions.compactMap { session in
            guard let pieceID = session.pieceID,
                  seenPieceIDs.insert(pieceID).inserted
            else {
                return nil
            }

            return activePieceLookup[pieceID]
        }

        let practicedPieceIDsLast30 = Set(sessionsLast30.compactMap(\.pieceID))
        piecesNotPracticedRecently = activePieces.filter { piece in
            practicedPieceIDsLast30.contains(piece.id) == false
        }
    }
}

extension Array where Element == PracticeSession {
    nonisolated func sortedForPracticeHistory() -> [PracticeSession] {
        sorted { leftSession, rightSession in
            if leftSession.date != rightSession.date {
                return leftSession.date > rightSession.date
            }

            return leftSession.id.uuidString < rightSession.id.uuidString
        }
    }
}

extension Array where Element == PracticePiece {
    nonisolated func sortedForPracticePieces() -> [PracticePiece] {
        sorted { leftPiece, rightPiece in
            let titleComparison = leftPiece.title.localizedCaseInsensitiveCompare(rightPiece.title)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            let leftComposer = leftPiece.composer ?? ""
            let rightComposer = rightPiece.composer ?? ""
            let composerComparison = leftComposer.localizedCaseInsensitiveCompare(rightComposer)
            if composerComparison != .orderedSame {
                return composerComparison == .orderedAscending
            }

            return leftPiece.id.uuidString < rightPiece.id.uuidString
        }
    }
}
