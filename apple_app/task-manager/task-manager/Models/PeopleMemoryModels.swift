import Foundation

nonisolated enum PeopleStudyRating: String, CaseIterable, Codable, Hashable, Sendable {
    case easy
    case almost
    case missed

    var displayName: String {
        switch self {
        case .easy:
            return "Easy"
        case .almost:
            return "Almost"
        case .missed:
            return "Missed"
        }
    }
}

nonisolated struct PersonTag: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var normalizedKey: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        normalizedKey: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedKey = normalizedKey ?? Self.normalizedKey(for: self.name)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init?(newName: String, createdAt: Date = .now) {
        guard let cleanedName = Self.cleanedName(from: newName) else {
            return nil
        }

        self.init(name: cleanedName, createdAt: createdAt)
    }

    static func cleanedName(from rawName: String) -> String? {
        MyTask.cleanedTitle(from: rawName)
    }

    static func normalizedKey(for rawName: String) -> String {
        rawName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

nonisolated struct PersonMemory: Identifiable, Equatable, Sendable {
    static let studyIntervalsInDays = [0, 1, 3, 7, 14, 30]

    let id: UUID
    var name: String
    var pronunciationNote: String?
    var whereMet: String?
    var metAt: Date?
    var context: String?
    var recognitionCues: String?
    var conversationHooks: String?
    var notes: String?
    var tagIDs: [UUID]
    var studyStage: Int
    var reviewCount: Int
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
    var lastStudyRating: PeopleStudyRating?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        pronunciationNote: String? = nil,
        whereMet: String? = nil,
        metAt: Date? = nil,
        context: String? = nil,
        recognitionCues: String? = nil,
        conversationHooks: String? = nil,
        notes: String? = nil,
        tagIDs: [UUID] = [],
        studyStage: Int = 0,
        reviewCount: Int = 0,
        lastReviewedAt: Date? = nil,
        nextReviewAt: Date? = nil,
        lastStudyRating: PeopleStudyRating? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pronunciationNote = MyTask.cleanedOptionalText(from: pronunciationNote)
        self.whereMet = MyTask.cleanedOptionalText(from: whereMet)
        self.metAt = metAt
        self.context = MyTask.cleanedOptionalText(from: context)
        self.recognitionCues = MyTask.cleanedOptionalText(from: recognitionCues)
        self.conversationHooks = MyTask.cleanedOptionalText(from: conversationHooks)
        self.notes = MyTask.cleanedOptionalText(from: notes)
        var seenTagIDs: Set<UUID> = []
        self.tagIDs = tagIDs.filter { seenTagIDs.insert($0).inserted }
        self.studyStage = Self.cleanedStudyStage(studyStage)
        self.reviewCount = max(0, reviewCount)
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
        self.lastStudyRating = lastStudyRating
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init?(
        newName: String,
        pronunciationNote: String? = nil,
        whereMet: String? = nil,
        metAt: Date? = nil,
        context: String? = nil,
        recognitionCues: String? = nil,
        conversationHooks: String? = nil,
        notes: String? = nil,
        tagIDs: [UUID] = [],
        createdAt: Date = .now
    ) {
        guard let cleanedName = Self.cleanedName(from: newName) else {
            return nil
        }

        self.init(
            name: cleanedName,
            pronunciationNote: pronunciationNote,
            whereMet: whereMet,
            metAt: metAt,
            context: context,
            recognitionCues: recognitionCues,
            conversationHooks: conversationHooks,
            notes: notes,
            tagIDs: tagIDs,
            createdAt: createdAt
        )
    }

    var hasRecallClue: Bool {
        whereMet != nil
            || context != nil
            || recognitionCues != nil
            || conversationHooks != nil
            || tagIDs.isEmpty == false
    }

    var isStudyReady: Bool {
        hasRecallClue
    }

    var needsEnrichment: Bool {
        hasRecallClue == false
    }

    func isDue(at date: Date) -> Bool {
        guard isStudyReady else {
            return false
        }

        return nextReviewAt.map { $0 <= date } ?? false
    }

    func matchesSearchText(_ query: String, tags: [PersonTag] = []) -> Bool {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedQuery.isEmpty == false else {
            return true
        }

        let searchableText = [
            name,
            pronunciationNote,
            whereMet,
            context,
            recognitionCues,
            conversationHooks,
            notes,
            tags.filter { tagIDs.contains($0.id) }.map(\.name).joined(separator: " "),
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        return searchableText.range(of: cleanedQuery, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    func applyingStudyRating(
        _ rating: PeopleStudyRating,
        reviewedAt: Date,
        calendar: Calendar = .current
    ) -> PersonMemory {
        var updated = self
        updated.lastReviewedAt = reviewedAt
        updated.lastStudyRating = rating
        updated.reviewCount += 1

        switch rating {
        case .easy:
            updated.studyStage = min(5, studyStage + 1)
            updated.nextReviewAt = Self.reviewDate(
                from: reviewedAt,
                stage: updated.studyStage,
                calendar: calendar
            )
        case .almost:
            updated.studyStage = max(1, studyStage)
            updated.nextReviewAt = calendar.date(byAdding: .day, value: 1, to: reviewedAt)
                ?? reviewedAt.addingTimeInterval(86_400)
        case .missed:
            updated.studyStage = 0
            updated.nextReviewAt = reviewedAt
        }

        updated.updatedAt = reviewedAt
        return updated
    }

    static func cleanedName(from rawName: String) -> String? {
        MyTask.cleanedTitle(from: rawName)
    }

    static func cleanedStudyStage(_ stage: Int) -> Int {
        min(5, max(0, stage))
    }

    private static func reviewDate(
        from date: Date,
        stage: Int,
        calendar: Calendar
    ) -> Date {
        let interval = studyIntervalsInDays[cleanedStudyStage(stage)]
        return calendar.date(byAdding: .day, value: interval, to: date)
            ?? date.addingTimeInterval(TimeInterval(interval * 86_400))
    }
}

nonisolated struct PeopleStudyCard: Identifiable, Equatable, Sendable {
    let person: PersonMemory
    let tags: [PersonTag]

    var id: UUID {
        person.id
    }
}

nonisolated struct HomePeopleMemorySummary: Equatable, Sendable {
    let people: [PersonMemory]
    let now: Date

    var totalCount: Int {
        people.count
    }

    var dueCount: Int {
        people.filter { $0.isDue(at: now) }.count
    }

    var detail: String {
        if dueCount > 0 {
            return "\(dueCount) due"
        }

        if totalCount > 0 {
            return "\(totalCount) saved"
        }

        return "No people yet"
    }
}

nonisolated enum PeopleStudyQueue {
    static func cards(
        from people: [PersonMemory],
        tags: [PersonTag],
        now: Date,
        limit: Int = 5
    ) -> [PeopleStudyCard] {
        let tagLookup = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })

        return Array(
            people
                .filter(\.isStudyReady)
                .sorted { leftPerson, rightPerson in
                    sortKey(for: leftPerson, now: now) < sortKey(for: rightPerson, now: now)
                }
                .prefix(max(0, limit))
                .map { person in
                    PeopleStudyCard(
                        person: person,
                        tags: person.tagIDs.compactMap { tagLookup[$0] }
                    )
                }
        )
    }

    private static func sortKey(for person: PersonMemory, now: Date) -> PeopleStudySortKey {
        if person.isDue(at: now) {
            return PeopleStudySortKey(bucket: 0, date: person.nextReviewAt ?? .distantPast, id: person.id)
        }

        if person.lastReviewedAt == nil {
            return PeopleStudySortKey(bucket: 1, date: person.createdAt, id: person.id)
        }

        return PeopleStudySortKey(bucket: 2, date: person.lastReviewedAt ?? .distantPast, id: person.id)
    }
}

private struct PeopleStudySortKey: Comparable {
    let bucket: Int
    let date: Date
    let id: UUID

    static func < (lhs: PeopleStudySortKey, rhs: PeopleStudySortKey) -> Bool {
        if lhs.bucket != rhs.bucket {
            return lhs.bucket < rhs.bucket
        }

        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}
