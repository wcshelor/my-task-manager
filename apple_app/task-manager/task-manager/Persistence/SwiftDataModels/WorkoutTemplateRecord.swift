import Foundation
import SwiftData

@Model
final class WorkoutTemplateRecord {
    var id: UUID = UUID()
    var name: String = ""
    var exerciseIDsData: Data = Data()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(template: WorkoutTemplate) {
        update(from: template)
    }

    var template: WorkoutTemplate {
        WorkoutTemplate(
            id: id,
            name: name,
            exerciseIDs: Self.decode([UUID].self, from: exerciseIDsData) ?? [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from template: WorkoutTemplate) {
        id = template.id
        name = template.name
        exerciseIDsData = Self.encode(template.exerciseIDs)
        createdAt = template.createdAt
        updatedAt = template.updatedAt
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}
