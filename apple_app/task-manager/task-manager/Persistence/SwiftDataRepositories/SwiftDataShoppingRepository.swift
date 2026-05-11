import Foundation
import SwiftData

@MainActor
final class SwiftDataShoppingRepository: ShoppingRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchShoppingItems(includeHistory: Bool = false) throws -> [ShoppingItem] {
        let items = try fetchAllRecords().map(\.item)

        if includeHistory {
            return items.sortedForShoppingTrips()
        }

        return items.filter(\.isActive).sortedForShoppingTrips()
    }

    func fetchActiveShoppingItems() throws -> [ShoppingItem] {
        try fetchShoppingItems(includeHistory: false)
    }

    func fetchShoppingHistory() throws -> [ShoppingItem] {
        try fetchAllRecords()
            .map(\.item)
            .filter { $0.isActive == false }
            .sorted { leftItem, rightItem in
                let leftDate = leftItem.completedAt ?? leftItem.updatedAt
                let rightDate = rightItem.completedAt ?? rightItem.updatedAt

                if leftDate != rightDate {
                    return leftDate > rightDate
                }

                return leftItem.id.uuidString < rightItem.id.uuidString
            }
    }

    func shoppingItem(withID id: UUID) throws -> ShoppingItem? {
        try fetchRecord(withID: id)?.item
    }

    func saveShoppingItem(_ item: ShoppingItem, replacingItemWithID originalID: UUID?) throws {
        let record =
            try fetchRecord(withID: originalID ?? item.id)
            ?? fetchRecord(withID: item.id)

        if let record {
            record.update(from: item)
        } else {
            modelContext.insert(ShoppingItemRecord(item: item))
        }

        try modelContext.save()
    }

    func updateShoppingItemStatus(
        withID id: UUID,
        status: ShoppingItemStatus,
        at date: Date
    ) throws {
        guard let item = try shoppingItem(withID: id) else {
            return
        }

        try saveShoppingItem(
            item.updatingStatus(status, at: date),
            replacingItemWithID: id
        )
    }

    func deleteShoppingItem(withID id: UUID) throws {
        guard let record = try fetchRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchAllRecords() throws -> [ShoppingItemRecord] {
        try modelContext.fetch(FetchDescriptor<ShoppingItemRecord>())
    }

    private func fetchRecord(withID id: UUID) throws -> ShoppingItemRecord? {
        try fetchAllRecords().first { $0.id == id }
    }
}
