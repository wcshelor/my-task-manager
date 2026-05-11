import Foundation

nonisolated enum ShoppingUrgency: String, CaseIterable, Codable, Sendable {
    case needSoon
    case nextTrip
    case someday

    var displayName: String {
        switch self {
        case .needSoon:
            return "Need Soon"
        case .nextTrip:
            return "Next Trip"
        case .someday:
            return "Someday"
        }
    }

    var sortPriority: Int {
        switch self {
        case .needSoon:
            return 0
        case .nextTrip:
            return 1
        case .someday:
            return 2
        }
    }
}

nonisolated enum ShoppingNecessity: String, CaseIterable, Codable, Sendable {
    case necessary
    case useful
    case optional

    var displayName: String {
        rawValue.capitalized
    }

    var sortPriority: Int {
        switch self {
        case .necessary:
            return 0
        case .useful:
            return 1
        case .optional:
            return 2
        }
    }
}

nonisolated enum ShoppingItemStatus: String, CaseIterable, Codable, Sendable {
    case needed
    case bought
    case skipped
    case archived

    var displayName: String {
        switch self {
        case .needed:
            return "Needed"
        case .bought:
            return "Bought"
        case .skipped:
            return "Skipped"
        case .archived:
            return "Archived"
        }
    }

    var isActive: Bool {
        self == .needed
    }
}

nonisolated struct ShoppingItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var notes: String?
    var category: String?
    var storeType: String?
    var storeName: String?
    var urgency: ShoppingUrgency
    var necessity: ShoppingNecessity
    var status: ShoppingItemStatus
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        category: String? = nil,
        storeType: String? = nil,
        storeName: String? = nil,
        urgency: ShoppingUrgency = .nextTrip,
        necessity: ShoppingNecessity = .necessary,
        status: ShoppingItemStatus = .needed,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        let cleanedUpdatedAt = updatedAt ?? createdAt

        self.id = id
        self.title = Self.cleanedTitle(from: title) ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = Self.cleanedOptionalText(from: notes)
        self.category = Self.cleanedOptionalText(from: category)
        self.storeType = Self.cleanedOptionalText(from: storeType)
        self.storeName = Self.cleanedOptionalText(from: storeName)
        self.urgency = urgency
        self.necessity = necessity
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = cleanedUpdatedAt
        self.completedAt = status.isActive ? nil : (completedAt ?? cleanedUpdatedAt)
    }

    init?(newTitle: String, createdAt: Date = .now) {
        guard let cleanedTitle = Self.cleanedTitle(from: newTitle) else {
            return nil
        }

        self.init(title: cleanedTitle, createdAt: createdAt)
    }

    var isActive: Bool {
        status.isActive
    }

    var tripGroupName: String {
        storeType ?? "Unspecified"
    }

    func updatingStatus(
        _ status: ShoppingItemStatus,
        at date: Date
    ) -> ShoppingItem {
        ShoppingItem(
            id: id,
            title: title,
            notes: notes,
            category: category,
            storeType: storeType,
            storeName: storeName,
            urgency: urgency,
            necessity: necessity,
            status: status,
            createdAt: createdAt,
            updatedAt: date,
            completedAt: status.isActive ? nil : date
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

nonisolated struct ShoppingTripGroup: Identifiable, Equatable, Sendable {
    let storeType: String?
    let items: [ShoppingItem]

    var id: String {
        storeType ?? "Unspecified"
    }

    var title: String {
        storeType ?? "Unspecified"
    }
}

extension Array where Element == ShoppingItem {
    func sortedForShoppingTrips() -> [ShoppingItem] {
        sorted { leftItem, rightItem in
            let leftStore = leftItem.tripGroupName.localizedLowercase
            let rightStore = rightItem.tripGroupName.localizedLowercase

            if leftStore != rightStore {
                return leftStore < rightStore
            }

            if leftItem.urgency.sortPriority != rightItem.urgency.sortPriority {
                return leftItem.urgency.sortPriority < rightItem.urgency.sortPriority
            }

            if leftItem.necessity.sortPriority != rightItem.necessity.sortPriority {
                return leftItem.necessity.sortPriority < rightItem.necessity.sortPriority
            }

            if leftItem.createdAt != rightItem.createdAt {
                return leftItem.createdAt < rightItem.createdAt
            }

            return leftItem.id.uuidString < rightItem.id.uuidString
        }
    }
}
