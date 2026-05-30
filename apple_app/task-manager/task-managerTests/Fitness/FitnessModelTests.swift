import Foundation
import Testing
@testable import task_manager

struct FitnessModelTests {
    @Test func fitnessExerciseRejectsEmptyNamesAndRequiresRelevantUnits() {
        #expect(FitnessExercise(
            newName: "  ",
            tag: .push,
            trackingStyle: .strengthSets,
            weightUnit: .pounds
        ) == nil)
        #expect(FitnessExercise(
            newName: "Bench Press",
            tag: .push,
            trackingStyle: .strengthSets,
            weightUnit: nil
        ) == nil)
        #expect(FitnessExercise(
            newName: "Bike",
            tag: .cardio,
            trackingStyle: .metricSummary,
            selectableMetricFields: [.durationMinutes, .distance],
            distanceUnit: nil
        ) == nil)

        let exercise = FitnessExercise(
            name: "  Pull Up  ",
            tag: .pull,
            trackingStyle: .strengthSets,
            selectableMetricFields: [.distance],
            weightUnit: .kilograms,
            distanceUnit: .miles
        )

        #expect(exercise.name == "Pull Up")
        #expect(exercise.weightUnit == .kilograms)
        #expect(exercise.distanceUnit == nil)
        #expect(exercise.selectableMetricFields.isEmpty)
    }

    @Test func workoutTemplateRequiresExercisesAndDeduplicatesWhilePreservingOrder() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        #expect(WorkoutTemplate(newName: "Push Day", exerciseIDs: []) == nil)

        let template = WorkoutTemplate(
            name: "  Push Day  ",
            exerciseIDs: [firstID, secondID, firstID, secondID]
        )

        #expect(template.name == "Push Day")
        #expect(template.exerciseIDs == [firstID, secondID])
    }

    @Test func metricSummaryExercisesRequireAtLeastOneField() {
        #expect(FitnessExercise(
            newName: "Bike",
            tag: .cardio,
            trackingStyle: .metricSummary,
            selectableMetricFields: []
        ) == nil)

        let exercise = FitnessExercise(
            newName: "Bike",
            tag: .cardio,
            trackingStyle: .metricSummary,
            selectableMetricFields: [.durationMinutes, .averageRPM]
        )

        #expect(exercise?.distanceUnit == nil)
        #expect(exercise?.selectableMetricFields == [.durationMinutes, .averageRPM])
    }

    @Test func exerciseSessionValidationMatchesExerciseStyle() {
        let strengthExercise = FitnessExercise(
            name: "Squat",
            tag: .legs,
            trackingStyle: .strengthSets,
            weightUnit: .pounds
        )
        let bikeExercise = FitnessExercise(
            name: "Bike",
            tag: .cardio,
            trackingStyle: .metricSummary,
            selectableMetricFields: [.durationMinutes, .distance],
            distanceUnit: .miles
        )
        let strengthSession = ExerciseSession(
            exerciseID: strengthExercise.id,
            strengthSets: [StrengthSet(reps: 5, weight: 225)]
        )
        let invalidStrengthSession = ExerciseSession(exerciseID: strengthExercise.id)
        let metricSession = ExerciseSession(
            exerciseID: bikeExercise.id,
            durationMinutes: 20,
            distance: 5.5
        )
        let invalidMetricSession = ExerciseSession(
            exerciseID: bikeExercise.id,
            durationMinutes: 20
        )

        #expect(strengthSession.isValid(for: strengthExercise))
        #expect(invalidStrengthSession.isValid(for: strengthExercise) == false)
        #expect(metricSession.isValid(for: bikeExercise))
        #expect(invalidMetricSession.isValid(for: bikeExercise) == false)
    }
}
