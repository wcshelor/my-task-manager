import Foundation
import SwiftData

@Model
final class ShoppingItemRecord {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var category: String?
    var storeType: String?
    var storeName: String?
    var urgencyRawValue: String = ShoppingUrgency.nextTrip.rawValue
    var necessityRawValue: String = ShoppingNecessity.necessary.rawValue
    var statusRawValue: String = ShoppingItemStatus.needed.rawValue
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var completedAt: Date?

    init(item: ShoppingItem) {
        update(from: item)
    }

    var item: ShoppingItem {
        ShoppingItem(
            id: id,
            title: title,
            notes: notes,
            category: category,
            storeType: storeType,
            storeName: storeName,
            urgency: ShoppingUrgency(rawValue: urgencyRawValue) ?? .nextTrip,
            necessity: ShoppingNecessity(rawValue: necessityRawValue) ?? .necessary,
            status: ShoppingItemStatus(rawValue: statusRawValue) ?? .needed,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt
        )
    }

    func update(from item: ShoppingItem) {
        id = item.id
        title = item.title
        notes = item.notes
        category = item.category
        storeType = item.storeType
        storeName = item.storeName
        urgencyRawValue = item.urgency.rawValue
        necessityRawValue = item.necessity.rawValue
        statusRawValue = item.status.rawValue
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        completedAt = item.completedAt
    }
}

