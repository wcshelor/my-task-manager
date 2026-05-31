import Foundation

nonisolated struct Vice: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var unitLabel: String
    let createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        unitLabel: String,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unitLabel = Self.cleanedUnitLabel(from: unitLabel) ?? unitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.isArchived = isArchived
    }

    init?(
        newName: String,
        unitLabel: String,
        createdAt: Date = .now
    ) {
        guard let cleanedName = Self.cleanedName(from: newName),
              let cleanedUnitLabel = Self.cleanedUnitLabel(from: unitLabel) else {
            return nil
        }

        self.init(
            name: cleanedName,
            unitLabel: cleanedUnitLabel,
            createdAt: createdAt
        )
    }

    static func cleanedName(from rawName: String) -> String? {
        MyTask.cleanedTitle(from: rawName)
    }

    static func cleanedUnitLabel(from rawLabel: String) -> String? {
        MyTask.cleanedTitle(from: rawLabel)
    }
}

nonisolated struct ViceLog: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let viceID: UUID
    let timestamp: Date
    let amount: Int

    init(
        id: UUID = UUID(),
        viceID: UUID,
        timestamp: Date,
        amount: Int = 1
    ) {
        self.id = id
        self.viceID = viceID
        self.timestamp = timestamp
        self.amount = max(1, amount)
    }
}

nonisolated struct HomeVicesSummary: Equatable, Sendable {
    let vices: [Vice]
    let logs: [ViceLog]
    let now: Date
    let calendar: Calendar

    var activeViceCount: Int {
        vices.filter { $0.isArchived == false }.count
    }

    var totalTodayCount: Int {
        logs
            .filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
            .reduce(0) { partialResult, log in
                partialResult + log.amount
            }
    }

    var detail: String {
        if activeViceCount == 0 {
            return "No vices added"
        }

        if totalTodayCount == 0 {
            return "No logs today"
        }

        return "\(totalTodayCount) logged today"
    }

    var value: String {
        "\(activeViceCount)"
    }
}
