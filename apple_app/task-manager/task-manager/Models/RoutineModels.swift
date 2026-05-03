import Foundation

nonisolated enum RoutineWeekday: Int, CaseIterable, Codable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var shortName: String {
        switch self {
        case .sunday:
            return "Sun"
        case .monday:
            return "Mon"
        case .tuesday:
            return "Tue"
        case .wednesday:
            return "Wed"
        case .thursday:
            return "Thu"
        case .friday:
            return "Fri"
        case .saturday:
            return "Sat"
        }
    }
}

nonisolated struct RoutineItem: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var title: String
    var position: Int

    init(id: UUID = UUID(), title: String, position: Int) {
        self.id = id
        self.title = Self.cleanedTitle(from: title) ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.position = max(0, position)
    }

    static func cleanedTitle(from rawTitle: String) -> String? {
        let cleanedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle.isEmpty ? nil : cleanedTitle
    }
}

nonisolated struct Routine: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var notes: String?
    var activeWeekdays: [RoutineWeekday]
    var items: [RoutineItem]
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        activeWeekdays: [RoutineWeekday] = [],
        items: [RoutineItem],
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = MyTask.cleanedOptionalText(from: notes)
        self.activeWeekdays = Self.cleanedWeekdays(activeWeekdays)
        self.items = Self.cleanedItems(items)
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init?(newName: String, itemTitles: [String], activeWeekdays: [RoutineWeekday] = []) {
        guard let cleanedName = Self.cleanedName(from: newName) else {
            return nil
        }

        let cleanedItems = itemTitles.enumerated().compactMap { index, title in
            RoutineItem.cleanedTitle(from: title).map {
                RoutineItem(title: $0, position: index)
            }
        }

        guard cleanedItems.isEmpty == false else {
            return nil
        }

        self.init(name: cleanedName, activeWeekdays: activeWeekdays, items: cleanedItems)
    }

    var isDaily: Bool {
        activeWeekdays.isEmpty
    }

    func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isArchived == false else {
            return false
        }

        guard isDaily == false else {
            return true
        }

        let weekday = calendar.component(.weekday, from: date)
        return activeWeekdays.contains { $0.rawValue == weekday }
    }

    var orderedItems: [RoutineItem] {
        items.sorted { leftItem, rightItem in
            if leftItem.position != rightItem.position {
                return leftItem.position < rightItem.position
            }

            return leftItem.id.uuidString < rightItem.id.uuidString
        }
    }

    static func cleanedName(from rawName: String) -> String? {
        let cleanedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedName.isEmpty ? nil : cleanedName
    }

    static func cleanedWeekdays(_ weekdays: [RoutineWeekday]) -> [RoutineWeekday] {
        Array(Set(weekdays)).sorted { $0.rawValue < $1.rawValue }
    }

    static func cleanedItems(_ items: [RoutineItem]) -> [RoutineItem] {
        items
            .compactMap { item -> RoutineItem? in
                guard let cleanedTitle = RoutineItem.cleanedTitle(from: item.title) else {
                    return nil
                }

                return RoutineItem(id: item.id, title: cleanedTitle, position: item.position)
            }
            .sorted { leftItem, rightItem in
                if leftItem.position != rightItem.position {
                    return leftItem.position < rightItem.position
                }

                return leftItem.id.uuidString < rightItem.id.uuidString
            }
    }
}

nonisolated struct RoutineCompletionLog: Identifiable, Equatable, Sendable {
    let id: UUID
    var routineID: UUID
    var date: Date
    var completedItemIDs: Set<UUID>
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        routineID: UUID,
        date: Date,
        completedItemIDs: Set<UUID> = [],
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.routineID = routineID
        self.date = date
        self.completedItemIDs = completedItemIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    func completionCount(for routine: Routine) -> Int {
        routine.orderedItems.filter { completedItemIDs.contains($0.id) }.count
    }

    func isComplete(for routine: Routine) -> Bool {
        let itemIDs = Set(routine.orderedItems.map(\.id))
        return itemIDs.isEmpty == false && itemIDs.isSubset(of: completedItemIDs)
    }

    mutating func setItem(_ itemID: UUID, completed: Bool, updatedAt: Date = .now) {
        if completed {
            completedItemIDs.insert(itemID)
        } else {
            completedItemIDs.remove(itemID)
        }

        self.updatedAt = updatedAt
    }
}
