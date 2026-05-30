import Foundation
import SwiftData

@Model
final class PersonTagRecord {
    var id: UUID = UUID()
    var name: String = ""
    var normalizedKey: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(tag: PersonTag) {
        update(from: tag)
    }

    var tag: PersonTag {
        PersonTag(
            id: id,
            name: name,
            normalizedKey: normalizedKey,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from tag: PersonTag) {
        id = tag.id
        name = tag.name
        normalizedKey = PersonTag.normalizedKey(for: tag.normalizedKey.isEmpty ? tag.name : tag.normalizedKey)
        createdAt = tag.createdAt
        updatedAt = tag.updatedAt
    }
}
