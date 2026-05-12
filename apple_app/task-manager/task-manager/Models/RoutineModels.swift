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

nonisolated enum RoutineStepLinkKind: String, CaseIterable, Codable, Sendable {
    case pvtTest
    case promiseCheckIn

    var displayTitle: String {
        switch self {
        case .pvtTest:
            return "PVT Test"
        case .promiseCheckIn:
            return "Promises"
        }
    }
}

nonisolated struct RoutineStepLink: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var routineStepID: UUID
    var kind: RoutineStepLinkKind
    var displayTitle: String
    var displayOrder: Int

    init(
        id: UUID = UUID(),
        routineStepID: UUID,
        kind: RoutineStepLinkKind,
        displayTitle: String? = nil,
        displayOrder: Int
    ) {
        self.id = id
        self.routineStepID = routineStepID
        self.kind = kind
        self.displayTitle = Routine.cleanedName(from: displayTitle ?? kind.displayTitle) ?? kind.displayTitle
        self.displayOrder = max(0, displayOrder)
    }
}

nonisolated struct Routine: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var notes: String?
    var activeWeekdays: [RoutineWeekday]
    var items: [RoutineItem]
    var stepLinks: [RoutineStepLink]
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        activeWeekdays: [RoutineWeekday] = [],
        items: [RoutineItem],
        stepLinks: [RoutineStepLink] = [],
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = MyTask.cleanedOptionalText(from: notes)
        self.activeWeekdays = Self.cleanedWeekdays(activeWeekdays)
        self.items = Self.cleanedItems(items)
        self.stepLinks = Self.cleanedStepLinks(stepLinks, validStepIDs: Set(self.items.map(\.id)))
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

    func orderedStepLinks(for stepID: UUID) -> [RoutineStepLink] {
        stepLinks
            .filter { $0.routineStepID == stepID }
            .sorted { leftLink, rightLink in
                if leftLink.displayOrder != rightLink.displayOrder {
                    return leftLink.displayOrder < rightLink.displayOrder
                }

                return leftLink.id.uuidString < rightLink.id.uuidString
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

    static func cleanedStepLinks(
        _ stepLinks: [RoutineStepLink],
        validStepIDs: Set<UUID>
    ) -> [RoutineStepLink] {
        stepLinks
            .filter { validStepIDs.contains($0.routineStepID) }
            .map { link in
                RoutineStepLink(
                    id: link.id,
                    routineStepID: link.routineStepID,
                    kind: link.kind,
                    displayTitle: link.displayTitle,
                    displayOrder: link.displayOrder
                )
            }
            .sorted { leftLink, rightLink in
                if leftLink.displayOrder != rightLink.displayOrder {
                    return leftLink.displayOrder < rightLink.displayOrder
                }

                return leftLink.id.uuidString < rightLink.id.uuidString
            }
    }
}

nonisolated struct RoutineCompletionLog: Identifiable, Equatable, Sendable {
    let id: UUID
    var routineID: UUID
    var date: Date
    var completedItemIDs: Set<UUID>
    var skippedItemIDs: Set<UUID>
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        routineID: UUID,
        date: Date,
        completedItemIDs: Set<UUID> = [],
        skippedItemIDs: Set<UUID> = [],
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.routineID = routineID
        self.date = date
        self.completedItemIDs = completedItemIDs
        self.skippedItemIDs = skippedItemIDs.subtracting(completedItemIDs)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    func completionCount(for routine: Routine) -> Int {
        routine.orderedItems.filter { completedItemIDs.contains($0.id) }.count
    }

    func skippedCount(for routine: Routine) -> Int {
        routine.orderedItems.filter { skippedItemIDs.contains($0.id) }.count
    }

    func isComplete(for routine: Routine) -> Bool {
        let itemIDs = Set(routine.orderedItems.map(\.id))
        return itemIDs.isEmpty == false && itemIDs.isSubset(of: completedItemIDs.union(skippedItemIDs))
    }

    func state(for itemID: UUID) -> RoutineStepCompletionState {
        if completedItemIDs.contains(itemID) {
            return .completed
        }

        if skippedItemIDs.contains(itemID) {
            return .skipped
        }

        return .untouched
    }

    mutating func setItem(
        _ itemID: UUID,
        state: RoutineStepCompletionState,
        updatedAt: Date = .now
    ) {
        switch state {
        case .completed:
            completedItemIDs.insert(itemID)
            skippedItemIDs.remove(itemID)
        case .skipped:
            completedItemIDs.remove(itemID)
            skippedItemIDs.insert(itemID)
        case .untouched:
            completedItemIDs.remove(itemID)
            skippedItemIDs.remove(itemID)
        }

        self.updatedAt = updatedAt
    }
}

nonisolated enum RoutineStepCompletionState: String, CaseIterable, Codable, Sendable {
    case untouched
    case completed
    case skipped
}
