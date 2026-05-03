import Foundation

nonisolated enum PromiseStatus: String, CaseIterable, Codable, Sendable {
    case active
    case resolved
    case archived

    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .resolved:
            return "Resolved"
        case .archived:
            return "Archived"
        }
    }
}

nonisolated enum PromiseOutcome: String, CaseIterable, Codable, Sendable {
    case kept
    case missed

    var displayName: String {
        switch self {
        case .kept:
            return "Kept"
        case .missed:
            return "Missed"
        }
    }
}

nonisolated struct Promise: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var notes: String?
    var startAt: Date
    var checkInAt: Date
    var whyItMatters: String?
    var expectedFriction: String?
    var status: PromiseStatus
    var outcome: PromiseOutcome?
    var reflection: String?
    var parentPromiseID: UUID?
    let createdAt: Date
    var updatedAt: Date
    var resolvedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        startAt: Date = .now,
        checkInAt: Date,
        whyItMatters: String? = nil,
        expectedFriction: String? = nil,
        status: PromiseStatus = .active,
        outcome: PromiseOutcome? = nil,
        reflection: String? = nil,
        parentPromiseID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        resolvedAt: Date? = nil
    ) {
        let cleanedUpdatedAt = updatedAt ?? createdAt

        self.id = id
        self.title = Self.cleanedTitle(from: title) ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = Self.cleanedOptionalText(from: notes)
        self.startAt = startAt
        self.checkInAt = max(checkInAt, startAt)
        self.whyItMatters = Self.cleanedOptionalText(from: whyItMatters)
        self.expectedFriction = Self.cleanedOptionalText(from: expectedFriction)
        self.status = status
        self.outcome = status == .resolved ? outcome : nil
        self.reflection = Self.cleanedOptionalText(from: reflection)
        self.parentPromiseID = parentPromiseID
        self.createdAt = createdAt
        self.updatedAt = cleanedUpdatedAt
        self.resolvedAt = status == .resolved ? (resolvedAt ?? cleanedUpdatedAt) : nil
    }

    init?(newTitle: String, startAt: Date = .now, checkInAt: Date) {
        guard let cleanedTitle = Self.cleanedTitle(from: newTitle) else {
            return nil
        }

        self.init(title: cleanedTitle, startAt: startAt, checkInAt: checkInAt)
    }

    var isActive: Bool {
        status == .active
    }

    func isDueForCheckIn(at date: Date) -> Bool {
        status == .active && checkInAt <= date
    }

    func isPresent(at date: Date) -> Bool {
        status == .active && startAt <= date
    }

    func resolved(
        outcome: PromiseOutcome,
        reflection: String?,
        resolvedAt: Date
    ) -> Promise {
        Promise(
            id: id,
            title: title,
            notes: notes,
            startAt: startAt,
            checkInAt: checkInAt,
            whyItMatters: whyItMatters,
            expectedFriction: expectedFriction,
            status: .resolved,
            outcome: outcome,
            reflection: reflection,
            parentPromiseID: parentPromiseID,
            createdAt: createdAt,
            updatedAt: resolvedAt,
            resolvedAt: resolvedAt
        )
    }

    static func cleanedTitle(from rawTitle: String) -> String? {
        let cleanedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle.isEmpty ? nil : cleanedTitle
    }

    static func cleanedOptionalText(from rawText: String?) -> String? {
        MyTask.cleanedOptionalText(from: rawText)
    }
}

extension Array where Element == Promise {
    func active(at date: Date) -> [Promise] {
        filter { $0.isPresent(at: date) }
    }

    func dueForCheckIn(at date: Date) -> [Promise] {
        filter { $0.isDueForCheckIn(at: date) }
    }
}
