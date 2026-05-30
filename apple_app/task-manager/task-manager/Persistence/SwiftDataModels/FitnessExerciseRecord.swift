import Foundation
import SwiftData

@Model
final class FitnessExerciseRecord {
    var id: UUID = UUID()
    var name: String = ""
    var tagRawValue: String = FitnessTag.push.rawValue
    var trackingStyleRawValue: String = ExerciseTrackingStyle.strengthSets.rawValue
    var selectableMetricFieldsData: Data = Data()
    var weightUnitRawValue: String?
    var distanceUnitRawValue: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(exercise: FitnessExercise) {
        update(from: exercise)
    }

    var exercise: FitnessExercise {
        FitnessExercise(
            id: id,
            name: name,
            tag: FitnessTag(rawValue: tagRawValue) ?? .push,
            trackingStyle: ExerciseTrackingStyle(rawValue: trackingStyleRawValue) ?? .strengthSets,
            selectableMetricFields: Self.decode([SelectableMetricField].self, from: selectableMetricFieldsData) ?? [],
            weightUnit: weightUnitRawValue.flatMap(WeightUnit.init(rawValue:)),
            distanceUnit: distanceUnitRawValue.flatMap(DistanceUnit.init(rawValue:)),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from exercise: FitnessExercise) {
        id = exercise.id
        name = exercise.name
        tagRawValue = exercise.tag.rawValue
        trackingStyleRawValue = exercise.trackingStyle.rawValue
        selectableMetricFieldsData = Self.encode(exercise.selectableMetricFields)
        weightUnitRawValue = exercise.weightUnit?.rawValue
        distanceUnitRawValue = exercise.distanceUnit?.rawValue
        createdAt = exercise.createdAt
        updatedAt = exercise.updatedAt
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}
